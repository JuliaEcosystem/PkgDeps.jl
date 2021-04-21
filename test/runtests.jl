using PkgDeps
using Test
using UUIDs

depot = joinpath(@__DIR__, "resources")


@testset "internal functions" begin
    @testset "_get_pkg_name" begin
        @testset "uuid to name" begin
            expected = "Case1"
            pkg_name = PkgDeps._get_pkg_name(UUID("00000000-1111-2222-3333-444444444444"); depots=depot)

            @test expected == pkg_name
        end

        @testset "exception" begin
            @test_throws NoUUIDMatch PkgDeps._get_pkg_name(UUID("00000000-0000-0000-0000-000000000000"); depots=depot)
        end
    end

    @testset "_get_pkg_uuid" begin
        @testset "name to uuid" begin
            expected = UUID("00000000-1111-2222-3333-444444444444")
            pkg_uuid = PkgDeps._get_pkg_uuid("Case1", "Foobar"; depots=depot)

            @test expected == pkg_uuid
        end

        @testset "exception" begin
            @test_throws PackageNotInRegistry PkgDeps._get_pkg_uuid("FakePackage", "Foobar"; depots=depot)
        end
    end

    @testset "_get_latest_version" begin
        expected = v"0.2.0"
        path = joinpath("resources", "registries", "General", "Case4")
        result = PkgDeps._get_latest_version(path)

        @test expected == result
    end
end

@testset "reachable_registries" begin
    @testset "specfic registry -- $(typeof(v))" for v in ("Foobar", ["Foobar"])
        registry = reachable_registries("Foobar"; depots=depot)

        @test registry.name == "Foobar"
    end

    @testset "all registries" begin
        registries = reachable_registries(; depots=depot)

        @test length(registries) == 2
    end
end

@testset "users" begin
    foobar_registry = reachable_registries("Foobar"; depots=depot)
    all_registries = reachable_registries(; depots=depot)

    @testset "specific registry" begin
        dependents = users("DownDep", "Foobar"; registries=[foobar_registry])

        @test length(dependents) == 2
        [@test case in dependents for case in ["Case1", "Case2"]]
    end

    @testset "all registries" begin
        dependents = users("DownDep", "Foobar"; registries=all_registries)

        @test length(dependents) == 3
        @test !("Case4" in dependents)
        [@test case in dependents for case in ["Case1", "Case2", "Case3"]]
    end
end
