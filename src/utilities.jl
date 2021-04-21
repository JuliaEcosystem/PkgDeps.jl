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
Use levenshtein distance to find packages closely named to pkg_to_compare
"""
function _find_alternative_packages(pkg_to_compare::String, packages::Array)
    pkg_to_compare = uppercase(pkg_to_compare)
    pkg_distances = [(REPL.levenshtein(uppercase(pkg), pkg_to_compare), pkg) for pkg in packages]
    sort!(pkg_distances)
    counts = [count(x -> x[1] <= i, pkg_distances) for i in 0:2]
    max_distance = max(0, searchsortedlast(counts, 8) - 1)

    return [pkg for (distance, pkg) in pkg_distances if distance <= max_distance]
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
        alt_packages = _find_alternative_packages(pkg_name, collect(keys(registry.pkgs)))

        warning = "The package $(pkg_name) was not found in the $(registry.name) registry."

        if !isempty(alt_packages)
            warning *= "\nPerhaps you meant: $(string(alt_packages))"
        end

        warning *= "\nOr you can search in another registry using `users(\"$(pkg_name)\"; pkg_registry_name=\"OtherRegistry\")`"
        throw(PackageNotInRegistry(warning))
    end
end
