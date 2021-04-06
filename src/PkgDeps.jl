module PkgDeps

using Pkg.Types: VersionNumber, VersionRange
using TOML: parsefile
using UUIDs

export PkgEntry, RegistryInstance
export find_downstream_dependencies, reachable_registries

include("pkg_entry.jl")
include("registry_instance.jl")


"""
    _get_latest_version(base_path::AbstractString)

Get the latest VersionNumber for base_path/Versions.toml

# Arguments
- `base_path::AbstractString`: Base path to look for Versions.toml

# Returns
- `VersionNumber`: Highest version number found in base_path/Versions.toml

# Throws
- `VersionTOMLNotFound`: Versions.toml does not exist at the base_path
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
    reachable_registries(registry_names::Array)

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
reachable_registries(; depots::Union{String, Vector{String}}=Base.DEPOT_PATH) = reachable_registries([]; depots=depots)
reachable_registries(registry_name::String; depots::Union{String, Vector{String}}=Base.DEPOT_PATH) = reachable_registries([registry_name]; depots=depots)


"""
    find_downstream_dependencies(pkg_name::AbstractString; registries::Array{PkgDeps.RegistryInstance}=reachable_registries())

Find all dependents of `pkg_name` for the current master version.

# Arguments
- `pkg_name::AbstractString`: Name of the package to find dependents

# Keywords
- `registries::Array{RegistryInstance}=reachable_registries()`: Registries to look into

# Returns
- `Array{String}`: List of packages which depend on `pkg_name`
"""
function find_downstream_dependencies(
    pkg_name::AbstractString;
    registries::Array{RegistryInstance}=reachable_registries()
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

end
