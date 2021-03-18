module PkgDeps

using TOML: parsefile
using UUIDs

export PkgEntry, RegistryInstance
export find_upstream_dependencies, reachable_registries

struct PkgEntry
    path::String
    registry_path::String
    name::String
    uuid::UUID
end

struct RegistryInstance
    path::String
    name::String
    uuid::UUID
    url::Union{String, Nothing}
    repo::Union{String, Nothing}
    description::Union{String, Nothing}
    pkgs::Dict{AbstractString, PkgEntry}
end

function RegistryInstance(path::AbstractString)
    d = parsefile(joinpath(path, "Registry.toml"))
    pkgs = Dict{AbstractString, PkgEntry}()

    for (uuid, info) in d["packages"]
        uuid = UUID(uuid)
        info
        name = info["name"]
        pkgpath = info["path"]
        pkg = PkgEntry(pkgpath, path, name, uuid)
        pkgs[name] = pkg
    end

    return RegistryInstance(
        path,
        d["name"],
        UUID(d["uuid"]),
        get(d, "url", nothing),
        get(d, "repo", nothing),
        get(d, "description", nothing),
        pkgs
    )
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
    find_upstream_dependencies(pkg_name::AbstractString; registries::Array{PkgDeps.RegistryInstance}=reachable_registries())

Find all dependents of `pkg_name` for the current master version.

# Arguments
- `pkg_name::AbstractString`: Name of the package to find dependents

# Keywords
- `registries::Array{RegistryInstance}=reachable_registries()`: Registries to look into

# Returns
- `Array{String}`: List of packages which depend on `pkg_name`
"""
function find_upstream_dependencies(pkg_name::AbstractString; registries::Array{RegistryInstance}=reachable_registries())
    upstream_dependencies = String[]

    for rego in registries
        for (pkg, v) in rego.pkgs
            path = joinpath(v.registry_path, v.path, "Deps.toml")

            if isfile(path)
                file_contents = parsefile(path)

                dep_keys = [k for k in collect(keys(file_contents)) if endswith(k, "-0") || k == "0"]

                deps = getindex.(Ref(file_contents), dep_keys)
                deps = vcat(collect.(keys.(deps))...)

                if pkg_name in deps
                    push!(upstream_dependencies, pkg)
                end
            end
        end
    end

    return upstream_dependencies
end

end
