module MAPPFD

import Random: seed!, randperm
import Printf: @printf, @sprintf
import Base: @kwdef, get
import DataStructures: PriorityQueue, enqueue!, dequeue!
using Plots
import ColorSchemes
import Base.Iterators: product

include("utils.jl")
include("graph.jl")
include("instance.jl")
include("single_agent_pathfinding.jl")
using .SingleAgentPathfinding
include("multi_agent_pathfinding.jl")
using .MultiAgentPathfinding
include("otimapp.jl")
using .OTIMAPP

# include("libsolver.jl")
# include("libsolver_seq.jl")
# include("exec.jl")
# include("complete_algo.jl")
include("examples.jl")
# include("viz.jl")

end # module
