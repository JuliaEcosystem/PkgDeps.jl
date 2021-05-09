module PkgDeps

using Pkg.Types: VersionNumber, VersionRange
using REPL
using TOML: parsefile
using UUIDs

export PkgEntry, RegistryInstance
export NoUUIDMatch, PackageNotInRegistry
export users, reachable_registries

include("pkg_entry.jl")
include("registry_instance.jl")
include("exceptions.jl")
include("utilities.jl")

const GENERAL_REGISTRY = "General"


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
    registries = RegistryInstance[]

    if depots isa String
        depots = [depots]
    end

    for d in depots
        isdir(d) || continue
        reg_dir = joinpath(d, "registries")
        isdir(reg_dir) || continue

        for name in readdir(reg_dir)
            if isempty(registry_names) || name in registry_names
                file = joinpath(reg_dir, name, "Registry.toml")
                isfile(file) || continue
                push!(registries, RegistryInstance(joinpath(reg_dir, name)))
            end
        end
    end

    return registries
end
reachable_registries(registry_name::String; depots::Union{String, Vector{String}}=Base.DEPOT_PATH, kwargs...) = reachable_registries([registry_name]; depots=depots, kwargs...)
reachable_registries(; depots::Union{String, Vector{String}}=Base.DEPOT_PATH, kwargs...) = reachable_registries([]; depots=depots, kwargs...)


"""
    users(uuid::UUID; registries::Array{RegistryInstance}=reachable_registries(), depots::Union{String, Vector{String}}=Base.DEPOT_PATH)
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
    depots::Union{String, Vector{String}}=Base.DEPOT_PATH
)
    downstream_dependencies = String[]

    for rego in registries
        for (pkg, v) in rego.pkgs
            base_path = joinpath(v.registry_path, v.path)
            deps_file_path = joinpath(base_path, "Deps.toml")

            if isfile(deps_file_path)
                deps_content = parsefile(deps_file_path)
                dependency_versions = collect(keys(deps_content))
                latest_version = _get_latest_version(base_path)

                # Use the latest_version of pkg, and check to see if pkg_name is in its dependents
                for version_range in dependency_versions
                    if in(latest_version, VersionRange(version_range))
                        dependencies = collect(values(deps_content[version_range]))
                        @show dependencies
                        # Check if pkg_name is used in the latest version of pkg
                        if uuid in dependencies
                            push!(downstream_dependencies, pkg)
                        end
                    end
                end
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

end  # module
