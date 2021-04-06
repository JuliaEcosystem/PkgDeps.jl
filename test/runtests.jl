using PkgDeps
using Test

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

@testset "find_downstream_dependencies" begin
    foobar_registry = reachable_registries("Foobar"; depots=depot)
    all_registries = reachable_registries(; depots=depot)

    @testset "specific registry" begin
        dependents = find_downstream_dependencies("DownDep"; registries=foobar_registry)

        @test length(dependents) == 2
        [@test case in dependents for case in ["Case1", "Case2"]]
    end

    @testset "all registries" begin
        dependents = find_downstream_dependencies("DownDep"; registries=all_registries)

        @test length(dependents) == 3
        @test !("Case4" in dependents)
        [@test case in dependents for case in ["Case1", "Case2", "Case3"]]
    end
end
