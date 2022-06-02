using Test
import Random: seed!
using MAPPFD
include("../scripts/instance_examples.jl")

const DIRNAME = "./local"
isdir(DIRNAME) && rm(DIRNAME, recursive = true)

macro test_savefig(name::String)
    return esc(quote
        filename = joinpath(DIRNAME, $name * ".png")
        MAPPFD.safe_savefig!(filename)
        @test isfile(filename)
    end)
end

include("./test_utils.jl")
include("./test_graph.jl")
include("./test_instance.jl")
include("./test_pathfinding.jl")
include("./test_mapf.jl")
include("./test_otimapp.jl")
include("./test_solver.jl")
include("./test_exec.jl")
include("./test_viz.jl")
include("./test_example.jl")
include("./test_scripts.jl")
