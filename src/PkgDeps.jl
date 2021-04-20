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
function _get_pkg_name(uuid::UUID; kwargs...)
    registries = reachable_registries(; kwargs...)

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
Get the UUID from a package name and the registry its in.
Specify a registry name as well to avoid ambiguity with same package names in multiple registries.
"""
function _get_pkg_uuid(
    pkg_name::String, registry_name::String;
    depots::Union{String, Vector{String}}=Base.DEPOT_PATH,
    kwargs...
)
    registry = reachable_registries(registry_name; depots=depots)

    if haskey(registry.pkgs, pkg_name)
        return registry.pkgs[pkg_name].uuid
    else
        throw(PackageNotInRegistry("$pkg_name not in $registry_name"))
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
    users(uuid::UUID; registries::Array{RegistryInstance}=reachable_registries())

Find the users of a given package.

# Arguments
- `uuid::UUID`: UUID of the package

# Keywords
- `registries::Array{RegistryInstance}=reachable_registries()`: Registry to find users in

# Returns
- `Array{String}`: All packages which are dependent on `pkg_name`
"""
function users(
    uuid::UUID;
    registries::Array{RegistryInstance}=reachable_registries(),
    kwargs...
)
    pkg_name = _get_pkg_name(uuid; kwargs...)
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
                        dependencies = collect(keys(deps_content[version_range]))

                        # Check if pkg_name is used in the latest version of pkg
                        if pkg_name in dependencies
                            push!(downstream_dependencies, pkg)
                        end
                    end
                end
            end
        end
    end

    return downstream_dependencies
end


"""
    users(pkg_name::String; pkg_registry_name::String="$GENERAL_REGISTRY")

Find all packages which use `pkg_name`. Use the `pkg_registry_name` to look up the UUID of `pkg_name`.

# Arguments
- `pkg_name::String`: Find users of this package

# Keywords
- `registry_name::String="$GENERAL_REGISTRY"`: Name of registry where `pkg_name` is active

# Returns
- `Array{String}`: All packages which are dependent on `pkg_name`
"""
function users(
    pkg_name::String;
    pkg_registry_name::String=GENERAL_REGISTRY,
    kwargs...
)
    uuid = _get_pkg_uuid(pkg_name, pkg_registry_name; kwargs...)
    return users(uuid; kwargs...)
end

end
