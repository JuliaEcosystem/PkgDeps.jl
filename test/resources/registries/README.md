## Creating test cases
When adding test cases please create another test case in any existing registry.
Include `Deps.toml` and `Versions.toml` files to specify when a package has been dependent
on another.


## Overview of Cases

### Case1
Single patch pre-1.0 release that has always been dependent on `DownDep`.

### Case2
Single minor pre-1.0 release that has always been dependent on `DownDep` and  `Statistics`

### Case3
Single post-1.0 release that is dependent on `DownDep`.

### Case4
Two releases where `DownDep` was previously a dependency and no longer is.

## ClashPkg

This package is registered in both `Foobar` and `General`, with a later version in `General`.

The version in `Foobar` depends on `Case2`, while the version in General depends on `Case4`.

## ClashUser1

This package uses the `ClashPkg` registered in `Foobar`.

## DownDep

This package is registered in `Foobar`
