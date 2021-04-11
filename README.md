# PkgDeps.jl

Small package to give more insightful information about package dependencies.


## Exports

### Functions

* `find_dependencies`: find all the dependencies of a package, including transitive ones
* `find_direct_dependencies`: find the direct dependencies of a package
* `find_direct_downstream_dependencies`: find all the packages which directly depend on a given package
* `reachable_registries`: collect the registries found in the given depot 

### Types

* `PkgEntry`: information about a package collected from a single registry
* `RegistryInstance`: information about a registry, including the packages it contains

## Quick example

```julia
julia> using PkgDeps

julia> find_dependencies("PkgDeps")
Set{String} with 4 elements:
  "Dates"
  "Pkg"
  "UUIDs"
  "TOML"

julia> find_direct_downstream_dependencies("Dates")
504-element Vector{String}:
 "Luxor"
 "BifurcationKit"
 "FeatherLib"
 "FymEnvs"
 "Matte"
 "Circuitscape"
 "AIBECS"
 "MonthlyDates"
 "Remarkable"
 "SentinelArrays"
 "Flick"
 ⋮
 "Vega"
 "UnetSockets"
 "Cambrian"
 "PooksoftAssetModelingKit"
 "QDates"
 "SGP4"
 "CSV"
 "ProjectAssistant"
 "Intan"
 "ULID"
 "Microeconometrics"
```
