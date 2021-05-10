# PkgDeps.jl

Small package to give more insightful information about package dependencies.

## Examples:

To find all packages that use [Tables.jl](https://github.com/JuliaData/Tables.jl) we use `users`

```julia
julia> users("Tables")
154-element Vector{String}:
 "CurrentPopulationSurvey"
 "Matte"
 "GeoStatsBase"
 "XLSX"
 ⋮
 "SQLite"
 "BraidChains"
 "PrettyTables"
 "CSV"
```

To find all the dependencies of a package, use `dependencies`, e.g.
```julia
julia> dependencies("DifferentialEquations")
Dict{String, Base.UUID} with 157 entries:
  "Pkg"                    => UUID("44cfe95a-1eb2-52ea-b672-e2afdf69b78f")
  "ForwardDiff"            => UUID("f6369f11-7733-5829-9624-2563aa707210")
  "RecursiveFactorization" => UUID("f2c3362d-daeb-58d1-803e-2bc74f2840b4")
  "SuiteSparse"            => UUID("4607b0f0-06f3-5cda-b6b1-a6196a1729e9")
  "ParameterizedFunctions" => UUID("65888b18-ceab-5e60-b2b9-181511a3b968")
  "DelayDiffEq"            => UUID("bcd4f6db-9728-5f36-b5f7-82caef46ccdb")
  "MuladdMacro"            => UUID("46d2c3a1-f734-5fdb-9937-b9b9aeba4221")
  "TableTraits"            => UUID("3783bdb8-4a98-5b6b-af9a-565f29a5fe9c")
  "OffsetArrays"           => UUID("6fe1bfb0-de20-5000-8ca7-80f57d26f881")
  "ConstructionBase"       => UUID("187b0558-2788-49d3-abe0-74a17ed4e7c9")
  "OrderedCollections"     => UUID("bac558e1-5e72-5ebc-8fee-abe8a469f55d")
  "MultiScaleArrays"       => UUID("f9640e96-87f6-5992-9c3b-0743c6a49ffa")
  "StochasticDiffEq"       => UUID("789caeaf-c7a9-5a7d-9973-96adeb23e2a0")
  ⋮                        => ⋮

```
