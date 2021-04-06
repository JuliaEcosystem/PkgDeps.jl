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
