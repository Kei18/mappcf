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
const MAPF = MultiAgentPathfinding
include("otimapp.jl")
using .OTIMAPP
include("solver.jl")
include("complete_algo.jl")

# include("exec.jl")
include("examples.jl")
include("viz.jl")

end # module
