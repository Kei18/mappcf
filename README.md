Multi-Agent Path Planning with Failure Detectors
---
[![MIT License](http://img.shields.io/badge/license-MIT-blue.svg?style=flat)](LICENCE.txt)
[![CI](https://github.com/Kei18/mappfd/actions/workflows/ci.yaml/badge.svg?branch=dev)](https://github.com/Kei18/mappfd/actions/workflows/ci.yaml)

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

c.f., xxxx sec with 16 threads

## Reproduction

### benchmark generation

```sh
julia --project=. --threads=auto
> include("./scripts/benchmark_gen.jl")
> @time create_benchmark("./scripts/config/benchmark/empty-8-8.yaml")
```

- change directory name

### baseline methods
```sh
julia --project=. --threads=auto -e "include(\"./scripts/eval_baseline.jl\")"
```

### sync

```sh
julia --project=. --threads=auto -e "include(\"./scripts/eval_sync.jl\")"
```

### seq

```sh
julia --project=. --threads=auto -e "include(\"./scripts/eval_seq.jl\")"
```

## Notes

## Licence
This software is released under the MIT License, see [LICENSE.txt](LICENCE.txt).

## Author
[Keisuke Okumura](https://kei18.github.io) is a Ph.D. student at the Tokyo Institute of Technology, interested in controlling multiple moving agents.

## Reference
