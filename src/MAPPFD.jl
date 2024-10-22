module MAPPFD

export
    # utils
    Deadline,
    generate_deadline,
    is_expired,
    verbose,
    # graph
    Graph,
    Vertex,
    add_edges!,
    remove_edges!,
    generate_grid,
    generate_random_grid,
    Config,
    Path,
    Paths,
    # instance
    Instance,
    SyncInstance,
    SeqInstance,
    generate_random_sync_instance_grid,
    generate_random_seq_instance_grid,
    generate_random_sync_instance_grid_wellformed,
    generate_random_seq_instance_grid_wellformed,
    generate_multiple_random_sync_instance_grid,
    generate_multiple_random_seq_instance_grid,
    generate_multiple_random_sync_instance_grid_wellformed,
    generate_multiple_random_seq_instance_grid_wellformed,
    # crash
    Crash,
    SyncCrash,
    SeqCrash,
    # solution
    Plan,
    Solution,
    get_scores,
    # execution
    execute_with_local_FD,
    approx_verify_with_local_FD,
    History,
    # viz
    plot_graph,
    plot_instance,
    plot_solution,
    safe_savefig!,
    plot_anim,
    plot_paths,
    # others
    MAPF,
    OTIMAPP,
    Failure

import Random: seed!, randperm
import Printf: @printf, @sprintf
import Base: @kwdef, get
import QuickHeaps: FastBinaryHeap
using Plots
import ColorSchemes
import Base.Threads
import JLD2

include("utils.jl")
include("graph.jl")
include("instance.jl")
include("crash.jl")
include("solution.jl")
include("./pathfinding/pathfinding.jl")
using .Pathfinding
include("./mapf/mapf.jl")
using .MAPF
include("./otimapp/otimapp.jl")
using .OTIMAPP
include("solver/solver.jl")
using .Solver
include("exec.jl")
include("viz.jl")

end # module
