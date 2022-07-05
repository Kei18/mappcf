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

#### generating benchmarks
```sh
julia --project=. --threads=auto
> include("./scripts/benchmark_gen.jl")
> @time create_benchmark("./scripts/config/benchmark/empty-8-8.yaml")
```

c.f., xxxx sec with 16 threads

#### evaluation

sync

```sh
julia --project=. --threads=auto
include("./scripts/eval.jl")
config_files = [
    "scripts/config/exp/commons.yaml",
    "scripts/config/exp/solvers_sync.yaml",
    "scripts/config/exp/random-32-32-10.yaml",
]
@time main(config_files, "instances.num=1000")
```

seq
```sh
julia --project=. --threads=auto
include("./scripts/eval.jl")
config_files = [
    "scripts/config/exp/commons.yaml",
    "scripts/config/exp/solvers_seq.yaml",
    "scripts/config/exp/random-32-32-10.yaml",
]
@time main(config_files, "instances.instance_type=SEQ", "instances.num=1000")
```


## Reproduction

## Notes

## Licence
This software is released under the MIT License, see [LICENSE.txt](LICENCE.txt).

## Author
[Keisuke Okumura](https://kei18.github.io) is a Ph.D. student at the Tokyo Institute of Technology, interested in controlling multiple moving agents.

## Reference
