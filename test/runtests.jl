using PkgDeps
using Test
using UUIDs

const DEPOT = joinpath(@__DIR__, "resources")
const GENERAL_REGISTRY = only(reachable_registries("General"; depots=DEPOT))
const FOOBAR_REGISTRY = only(reachable_registries("Foobar"; depots=DEPOT))

clashpkg_foobar_uuid = UUID("6402c8d7-2ba1-4f69-b0bd-e6ec13832549")
clashpkg_general_uuid = UUID("39dceb45-186c-466b-9eef-57dbb7902773")
all_registries = reachable_registries(; depots=DEPOT)

@testset "internal functions" begin
    @testset "_get_pkg_name" begin
        @testset "uuid to name" begin
            expected = "Case1"
            pkg_name = PkgDeps._get_pkg_name(UUID("00000000-1111-2222-3333-444444444444"); depots=DEPOT)

            @test expected == pkg_name
        end

        @testset "exception" begin
            @test_throws NoUUIDMatch PkgDeps._get_pkg_name(UUID("00000000-0000-0000-0000-000000000000"); registries=FOOBAR_REGISTRY)
        end
    end

    @testset "_get_pkg_uuid" begin
        @testset "name to uuid" begin
            expected = UUID("00000000-1111-2222-3333-444444444444")

            pkg_uuid = PkgDeps._get_pkg_uuid("Case1", "Foobar"; depots=DEPOT)
            @test expected == pkg_uuid

            pkg_uuid = PkgDeps._get_pkg_uuid("Case1", FOOBAR_REGISTRY)
            @test expected == pkg_uuid
        end

        @testset "Same name in two registries" begin
            @test clashpkg_foobar_uuid == PkgDeps._get_pkg_uuid("ClashPkg", "Foobar"; depots=DEPOT)
            @test clashpkg_general_uuid == PkgDeps._get_pkg_uuid("ClashPkg", "General"; depots=DEPOT)
        end

        @testset "exception" begin
            @test_throws PackageNotInRegistry PkgDeps._get_pkg_uuid("PkgDepsFakePackage", "General")
            @test_throws PackageNotInRegistry PkgDeps._get_pkg_uuid("FakePackage", FOOBAR_REGISTRY)
        end
    end

    @testset "_get_latest_version" begin
        expected = v"0.2.0"
        path = joinpath("resources", "registries", "General", "Case4")
        result = PkgDeps._get_latest_version(path)

        @test expected == result
    end

    @testset "_find_alternative_packages" begin
        MAX = 9
        pkg_to_compare = "package_name"
        packages = ["$(pkg_to_compare)_$(i)" for i in 1:MAX]

        result = PkgDeps._find_alternative_packages(pkg_to_compare, packages)
        @test length(result) == MAX
    end

    @testset "`_find_latest_pkg_entry`" begin
        entry = PkgDeps._find_latest_pkg_entry("ClashPkg"; registries=all_registries)
        # General has a later version of `ClashPkg`
        @test entry.uuid == clashpkg_general_uuid

        # No conflict here, so it should just find the right one
        entry = PkgDeps._find_latest_pkg_entry("Case4"; registries=all_registries)
        @test entry.uuid == UUID("172f9e6e-38ba-42e1-abf1-05c2c32c0454")

        entry = PkgDeps._find_latest_pkg_entry(missing, UUID("172f9e6e-38ba-42e1-abf1-05c2c32c0454"); registries=all_registries)
        @test entry.name == "Case4"

        @test_throws PackageNotInRegistry PkgDeps._find_latest_pkg_entry("FakePackage"; registries=all_registries)
        @test_throws ArgumentError PkgDeps._find_latest_pkg_entry(missing, missing; registries=all_registries)
    end
end

@testset "reachable_registries" begin
    @testset "specfic registry -- $(typeof(v))" for v in ("Foobar", ["Foobar"])
        registry = only(reachable_registries("Foobar"; depots=DEPOT))

        @test registry.name == "Foobar"
    end

    @testset "all registries" begin
        registries = reachable_registries(; depots=DEPOT)

        @test length(registries) == 2
    end
end

@testset "users" begin
    @testset "specific registry - registered in another registry" begin
        dependents = users("DownDep", FOOBAR_REGISTRY; registries=[GENERAL_REGISTRY], depots=DEPOT)

        @test length(dependents) == 1
        [@test case in dependents for case in ["Case3"]]
    end

    @testset "all registries" begin
        dependents = users("DownDep", FOOBAR_REGISTRY; registries=all_registries, depots=DEPOT)

        @test length(dependents) == 3
        @test !("Case4" in dependents)
        [@test case in dependents for case in ["Case1", "Case2", "Case3"]]
    end

    @testset "ClashPkg" begin
        dependents = users("ClashPkg", FOOBAR_REGISTRY; registries=all_registries, depots=DEPOT)
        @test dependents == ["ClashUser1"]

        dependents = users("ClashPkg", GENERAL_REGISTRY; registries=all_registries, depots=DEPOT)
        @test isempty(dependents)
    end

end

@testset "Dependencies" begin
    deps = dependencies("ClashPkg"; registries=all_registries)
    @test deps == Dict("Case4" => UUID("172f9e6e-38ba-42e1-abf1-05c2c32c0454"))
    deps = dependencies("ClashPkg"; registries=[GENERAL_REGISTRY])
    @test deps == Dict("Case4" => UUID("172f9e6e-38ba-42e1-abf1-05c2c32c0454"))

    deps = dependencies("ClashPkg"; registries=[FOOBAR_REGISTRY])
    @test deps == Dict("Case2" => UUID("a2a98da0-c97c-48ea-aa95-967bbb6a44f4"))

    deps = dependencies("Case4"; registries=all_registries)
    @test isempty(deps)
    deps = dependencies("Case2"; registries=all_registries)
    @test deps == Dict("DownDep" => UUID("000eeb74-f857-587a-a816-be5685e97e75"))
end
