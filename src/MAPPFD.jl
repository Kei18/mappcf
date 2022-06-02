module MAPPFD

export
    # graph
    Graph,
    Vertex,
    add_edges!,
    remove_edges!,
    generate_grid,
    generate_random_grid,
    # instance
    Config,
    SyncInstance,
    SeqInstance,
    generate_random_sync_instance_grid,
    generate_random_seq_instance_grid,
    # solution
    SyncCrash,
    SeqCrash,
    Plan,
    Solution,
    # execution
    execute_with_local_FD,
    execute_with_global_FD,
    approx_verify_with_local_FD,
    approx_verify_with_global_FD,
    History,
    # viz
    plot_graph,
    plot_instance,
    plot_solution,
    safe_savefig!,
    plot_anim,
    # others
    MAPF

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
include("exec.jl")
include("viz.jl")

include("examples.jl")

end # module
