module PkgDeps

using Pkg.Types: VersionNumber, VersionRange
using TOML: parsefile
using UUIDs

export PkgEntry, RegistryInstance
export NoUUIDMatch, PackageNotInRegistry
export users, reachable_registries

include("pkg_entry.jl")
include("registry_instance.jl")
include("exceptions.jl")

const GENERAL_REGISTRY = "General"


"""
Get the latest VersionNumber for base_path/Versions.toml
"""
function _get_latest_version(base_path::AbstractString)
    versions_file_path = joinpath(base_path, "Versions.toml")

    if isfile(versions_file_path)
        versions_content = parsefile(versions_file_path)
        versions = [VersionNumber(v) for v in collect(keys(versions_content))]

        return first(findmax(versions))
    end
end


"""
Get the package name from a UUID
"""
function _get_pkg_name(uuid::UUID; registries=reachable_registries())
    for rego in registries
        for (pkg_name, pkg_entry) in rego.pkgs
            if pkg_entry.uuid == uuid
                return pkg_name
            end
        end
    end

    throw(NoUUIDMatch("No package found with the UUID $uuid"))
end
_get_pkg_name(uuid::String; kwargs...) = _get_pkg_name(UUID(uuid); kwargs...)


"""
Get the UUID from a package name and the registry it is in.
Specify a registry name as well to avoid ambiguity with same package names in multiple registries.
"""
function _get_pkg_uuid(
    pkg_name::String, registry_name::String;
    depots::Union{String, Vector{String}}=Base.DEPOT_PATH,
)
    registry = reachable_registries(registry_name; depots=depots)
    return _get_pkg_uuid(pkg_name, registry)
end

function _get_pkg_uuid(pkg_name::String, registry::RegistryInstance)
    if haskey(registry.pkgs, pkg_name)
        return registry.pkgs[pkg_name].uuid
    else
        throw(PackageNotInRegistry("$pkg_name not in $(registry.name)"))
    end
end


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
    depots::Union{String, Vector{String}}=Base.DEPOT_PATH
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
reachable_registries(registry_name::String; depots::Union{String, Vector{String}}=Base.DEPOT_PATH) = first(reachable_registries([registry_name]; depots=depots))
reachable_registries(; depots::Union{String, Vector{String}}=Base.DEPOT_PATH) = reachable_registries([]; depots=depots)


"""
    users(uuid::UUID; kwargs...)
    users(pkg_name::String, pkg_registry_name::String="$GENERAL_REGISTRY"; kwargs...)

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
function users(uuid::UUID; registries::Array{RegistryInstance}=reachable_registries())
    pkg_name = _get_pkg_name(uuid; registries=registries)
    downstream_dependencies = String[]

    for rego in registries
        for (pkg, v) in rego.pkgs
            # Use the latest version of pkg, and check to see if pkg_name is in its dependents
            dependencies = find_direct_dependencies(v)
            if pkg_name in dependencies
                push!(downstream_dependencies, pkg)
            end
        end
    end

    return downstream_dependencies
end

function users(pkg_name::String, pkg_registry_name::String=GENERAL_REGISTRY; kwargs...)
    uuid = _get_pkg_uuid(pkg_name, pkg_registry_name)
    return users(uuid; kwargs...)
end

# Useful for testing using with registries not in `DEPOT_PATH`.
"""
    users(pkg_name::String, pkg_registry::RegistryInstance; kwargs...)

Find the users of the package named `pkg_name` which is registered in `pkg_registry`.
"""
function users(pkg_name::String, pkg_registry::RegistryInstance; kwargs...)
    uuid = _get_pkg_uuid(pkg_name, pkg_registry)
    return users(uuid; kwargs...)
end

"""
    find_direct_dependencies(pkg_name::AbstractString; registries::Array{PkgDeps.RegistryInstance}=reachable_registries())

Find all packages that the latest version of `pkg_name` directly depends on.

# Arguments
- `pkg_name::AbstractString`: Name of the package

# Keywords
- `registries::Array{RegistryInstance}=reachable_registries()`: Registries to look into

# Returns
- `Set{String}`: List of packages `pkg_name` directly depends on
"""
function find_direct_dependencies(
    pkg_name::AbstractString;
    registries::Array{RegistryInstance}=reachable_registries()
)
    upstream_dependencies = Set{String}()
    for rego in registries
        if haskey(rego.pkgs, pkg_name)
            union!(upstream_dependencies, find_direct_dependencies(repo.pkgs[pkg_name]))
        end
    end

    return upstream_dependencies
end

"""
    find_direct_dependencies(entry::PkgEntry)

Find all direct dependencies for the latest version of `entry` by parsing the `Deps.toml` file in the registry
associated to `entry.registry_path`.

# Arguments
- `entry::PkgEntry`: `PkgEntry` corresponding to the package

# Returns
- `Array{String}`: List of package names which are the direct dependencies of the latest version of `entry`.
"""
function find_direct_dependencies(entry::PkgEntry)
    latest_dependencies = String[]
    base_path = joinpath(entry.registry_path, entry.path)
    deps_file_path = joinpath(base_path, "Deps.toml")

    if isfile(deps_file_path)
        deps_content = parsefile(deps_file_path)
        dependency_versions = collect(keys(deps_content))
        latest_version = _get_latest_version(base_path)

        for version_range in dependency_versions
            if in(latest_version, VersionRange(version_range))
                dependencies = collect(keys(deps_content[version_range]))
                append!(latest_dependencies, dependencies)
            end
        end
    end

    return latest_dependencies
end


"""
    find_dependencies(pkg_name::AbstractString; registries::Array{RegistryInstance}=reachable_registries())

Find all packages that the latest version of `pkg_name` depends on (directly or indirectly).

# Arguments
- `pkg_name::AbstractString`: Name of the package

# Keywords
- `registries::Array{RegistryInstance}=reachable_registries()`: Registries to look into

# Returns
- `Set{String}`: List of packages which `pkg_name` depends on.
"""
function find_dependencies(
    pkg_name::AbstractString;
    registries::Array{RegistryInstance}=reachable_registries()
)
    return _find_dependencies!(Set{String}(), pkg_name; registries)
end

# recursive helper that accumulates into `upstream_dependencies`
function _find_dependencies!(
    upstream_dependencies::Set{String},
    pkg_name::AbstractString;
    registries::Array{RegistryInstance}=reachable_registries()
)
    for rego in registries
        if haskey(rego.pkgs, pkg_name)
            dependencies = find_direct_dependencies(rego.pkgs[pkg_name])
            for dependency in dependencies
                if dependency ∉ upstream_dependencies
                    push!(upstream_dependencies, dependency)
                    _find_dependencies!(upstream_dependencies, dependency; registries=registries)
                end
            end
        end
    end
    return upstream_dependencies
end

end  # module
