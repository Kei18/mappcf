Multi-Agent Path Planning with Failure Detectors
---
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENCE.txt)
[![CI](https://github.com/Kei18/mappfd/actions/workflows/ci.yaml/badge.svg?branch=dev)](https://github.com/Kei18/mappfd/actions/workflows/ci.yaml)

## TODO
- [ ] efficiently reuse heuristics function
- [ ] pre-compile
- [ ] concurrent

## Setup

```sh
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

## Minimum Example

## Utilities

#### Start JupyterNotebook
```sh
julia --project=. -e "using IJulia; jupyterlab()"
```

#### Test
```sh
julia --project=. -e 'using Pkg; Pkg.test()'
```

#### Formatting
```sh
julia --project=. -e 'using JuliaFormatter; format(".")'
```

adding auto formatting with commit

```sh
git config core.hooksPath .githooks
chmod a+x .githooks/pre-commit
```

#### generating benchmarks
```sh
julia --project=.
> include("./scripts/benchmark_gen.jl")
> benchmark_gen("./scripts/config/benchamrk/basic.yaml")
```

## Reproduction

## Notes

## Licence
This software is released under the MIT License, see [LICENSE.txt](LICENCE.txt).

## Author
[Keisuke Okumura](https://kei18.github.io) is a Ph.D. student at the Tokyo Institute of Technology, interested in controlling multiple moving agents.

## Reference
