module PkgDeps

using Pkg
using Pkg.Types: VersionNumber, VersionRange
using REPL
using TOML: parsefile
using UUIDs
using Compat
using RegistryInstances: RegistryInstances, PkgEntry, RegistryInstance

export PkgEntry, RegistryInstance
export NoUUIDMatch, PackageNotInRegistry
export users, reachable_registries
export direct_dependencies, dependencies

include("exceptions.jl")
include("utilities.jl")

const GENERAL_REGISTRY = "General"

# borrowed from <https://github.com/JuliaRegistries/RegistryTools.jl/blob/77cae9ef6a075e1d6ec1592bc3e166234d3f01c8/src/builtin_pkgs.jl>
const stdlibs = isdefined(Pkg.Types, :stdlib) ? Pkg.Types.stdlib : Pkg.Types.stdlibs
const STDLIBS = stdlibs()


"""
    reachable_registries(registry_names::Array)
    reachable_registries(registry_name::String; depots::Union{String, Vector{String}}=Base.DEPOT_PATH)
    reachable_registries(; depots::Union{String, Vector{String}}=Base.DEPOT_PATH)

Get an array of found registries.

# Arguments
- `registry_names::Array`: List of registries to retrieve

# Keywords
- `depots::Union{String, Vector{String}}=Base.DEPOT_PATH`: Depots to look in for registries

# Returns
- `Array{RegistryInstance}`: List of all found registries
"""
function reachable_registries(
    registry_names::Array;
    depots::Union{String, Vector{String}}=Base.DEPOT_PATH,
    kwargs...
)
    registries = RegistryInstances.reachable_registries(; depots)

    if isempty(registry_names)
        registries
    else
        filter(registries) do r
            r.name in registry_names
        end
    end
end
reachable_registries(registry_name::String; depots::Union{String, Vector{String}}=Base.DEPOT_PATH, kwargs...) = reachable_registries([registry_name]; depots=depots, kwargs...)
reachable_registries(; depots::Union{String, Vector{String}}=Base.DEPOT_PATH, kwargs...) = reachable_registries([]; depots=depots, kwargs...)


"""
    users(uuid::UUID; registries::Array{RegistryInstance}=reachable_registries())
    users(pkg_name::String, pkg_registry_name::String=GENERAL_REGISTRY; kwargs...)
    users(pkg_name::String, pkg_registry::RegistryInstance; kwargs...))

Find the users of a given package.

# Arguments
- `uuid::UUID`: UUID of the package.
- `pkg_name::String`: Find users of this package.
- `pkg_registry_name::String="$GENERAL_REGISTRY"`: Name of registry where `pkg_name` is
  registered. This is used to look up the UUID of `pkg_name`.

# Keywords
- `registries::Array{RegistryInstance}=reachable_registries()`: Registries to search for users.

# Returns
- `Array{String}`: All packages which are dependent on the given package.
"""
function users(
    uuid::UUID;
    registries::Array{RegistryInstance}=reachable_registries(),
)
    downstream_dependencies = String[]

    for rego in registries
        for pkg_entry in values(rego.pkgs)
            deps = direct_dependencies(pkg_entry)
            if any(isequal(uuid), values(deps))
                push!(downstream_dependencies, pkg_entry.name)
            end
        end
    end

    return downstream_dependencies
end

function users(pkg_name::String, pkg_registry_name::String=GENERAL_REGISTRY; kwargs...)
    uuid = _get_pkg_uuid(pkg_name, pkg_registry_name)
    return users(uuid; kwargs...)
end

function users(pkg_name::String, pkg_registry::RegistryInstance; kwargs...)
    uuid = _get_pkg_uuid(pkg_name, pkg_registry)
    return users(uuid; kwargs...)
end

"""
    direct_dependencies(pkg_name::String;
        registries::Array{RegistryInstance}=reachable_registries()) -> Dict{String, UUID}
    direct_dependencies(pkg_uuid::UUID; registries::Array{RegistryInstance}=reachable_registries()) -> Dict{String, UUID}
    
Returns the direct dependencies of the latest version of a given package
in the form of `Dict` with names as keys and UUIDs as values.

Standard libraries are assumed to not have any dependencies.
"""
direct_dependencies

function direct_dependencies(pkg_entry::PkgEntry)
    base_path = joinpath(pkg_entry.registry_path, pkg_entry.path)
    deps_file_path = joinpath(base_path, "Deps.toml")
    all_direct_dependencies = Dict{String, UUID}()

    if isfile(deps_file_path)
        deps_content = parsefile(deps_file_path)
        dependency_versions = collect(keys(deps_content))
        latest_version = _get_latest_version(base_path)

        # Use the latest_version of pkg, and check to see if pkg_name is in its dependents
        for version_range in dependency_versions
            if in(latest_version, VersionRange(version_range))
                for (k, v) in pairs(deps_content[version_range])
                    all_direct_dependencies[k] = UUID(v)
                end
            end
        end
    end

    return all_direct_dependencies
end

function direct_dependencies(pkg_name::String; registries::Array{RegistryInstance}=reachable_registries())
    if pkg_name in values(STDLIBS)
        return Dict{String, UUID}()
    end
    return direct_dependencies(_find_latest_pkg_entry(pkg_name, missing; registries))
end

function direct_dependencies(pkg_uuid::UUID; registries::Array{RegistryInstance}=reachable_registries())
    if pkg_uuid in keys(STDLIBS)
        return Dict{String, UUID}()
    end
    return direct_dependencies(_find_latest_pkg_entry(missing, pkg_uuid; registries))
end


"""
    dependencies(
        pkg_name::Union{AbstractString, Missing}, pkg_uuid::Union{Missing, UUID}=missing;
        registries::Array{RegistryInstance}=reachable_registries()
    )

Find all packages that the latest version of `pkg_name` depends on (directly or indirectly).

Note: each package in the dependency tree is assumed to be at the latest version; compat bounds
are ignored. Additionally, standard libraries are assumed to not have any dependencies.

# Arguments
- `pkg_name::AbstractString`: Name of the package
- `pkg_uuid::UUID`: UUID of the package, if available
# Keywords
- `registries::Array{RegistryInstance}=reachable_registries()`: Registries to look into
# Returns
- `Dict{String, UUID}()`: Packages which `pkg_name` depends on.
"""
function dependencies(
    pkg_name::Union{AbstractString, Missing}, pkg_uuid::Union{Missing, UUID}=missing;
    registries::Array{RegistryInstance}=reachable_registries()
)
    return _dependencies!(Dict{String, UUID}(), (pkg_name, pkg_uuid); registries)
end

function dependencies(
    uuid::UUID;
    registries::Array{RegistryInstance}=reachable_registries()
)
    return dependencies(missing, uuid; registries)
end


# recursive helper that accumulates into `deps_found`
function _dependencies!(
    deps_found::Dict{String, UUID},
    (name, uuid);
    registries::Array{RegistryInstance}=reachable_registries()
)
    if (uuid => name) in pairs(STDLIBS)
        return deps_found
    end

    direct_deps = direct_dependencies(_find_latest_pkg_entry(name, uuid; registries))
   
    for (dep_name, dep_uuid) in pairs(direct_deps)
        if dep_name ∈ keys(deps_found)
            if dep_uuid != deps_found[dep_name]
                error("Package (possibly transitively) depends on $(dep_name) twice, with different UUIDs: $(dep_uuid) and $(deps_found[dep_name])!")
            end
        else
            deps_found[dep_name] = dep_uuid
            _dependencies!(deps_found, (dep_name, dep_uuid); registries=registries)
        end
    end
   
    return deps_found
end

end  # module
