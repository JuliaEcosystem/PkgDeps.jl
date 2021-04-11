using PkgDeps
using Test

depot = joinpath(@__DIR__, "resources")
foobar_registry = reachable_registries("Foobar"; depots=depot)
all_registries = reachable_registries(; depots=depot)

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

@testset "find_direct_downstream_dependencies" begin
    @testset "specific registry" begin
        dependents = find_direct_downstream_dependencies("DownDep"; registries=foobar_registry)

        @test length(dependents) == 2
        [@test case in dependents for case in ["Case1", "Case2"]]
    end

    @testset "all registries" begin
        dependents = find_direct_downstream_dependencies("DownDep"; registries=all_registries)

        @test length(dependents) == 3
        @test !("Case4" in dependents)
        [@test case in dependents for case in ["Case1", "Case2", "Case3"]]
    end
end

@testset "`find_direct_dependencies`" begin
    @test find_direct_dependencies(foobar_registry[].pkgs["Case1"]) == ["DownDep"]
    @test find_direct_dependencies(foobar_registry[].pkgs["Case2"]) == ["DownDep"]

    general = reachable_registries("General"; depots=depot)[]
    @test find_direct_dependencies(general.pkgs["Case3"]) == ["DownDep"]
    @test find_direct_dependencies(general.pkgs["Case4"]) == String[]
end

@testset "`find_dependencies`" begin
    @test find_dependencies("Case1"; registries=foobar_registry) == Set(["DownDep"])
    @test find_dependencies("Case2"; registries=foobar_registry) == Set(["DownDep"])
    @test find_dependencies("Case3"; registries=all_registries) == Set(["DownDep"])
    @test find_dependencies("Case4"; registries=all_registries) == Set{String}()
    @test find_dependencies("Case5"; registries=all_registries) == Set(["Case3", "DownDep"])
end
