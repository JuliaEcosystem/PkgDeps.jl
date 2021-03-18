using PkgDeps
using Test
# Create some temp package TOML files
# Test that we get them properly

depot = joinpath(@__DIR__, "resources")

@testset "reachable_registries" begin
    @testset "specfic registry -- $(typeof(v))" for v in ("Foobar", ["Foobar"])
        registries = reachable_registries("Foobar"; depots=depot)

        @test length(registries) == 1
        @test registries[1].name == "Foobar"
    end

    @testset "all registries" begin
        registries = reachable_registries(; depots=depot)

        @test length(registries) == 2
    end
end

@testset "find_upstream_dependencies" begin
    registry = reachable_registries(; depots=depot)
    dependents = find_upstream_dependencies("UpDep"; registries=registry)

    @test length(dependents) == 3

    [@test case in dependents for case in ["Case1", "Case2", "Case3"]]
end
