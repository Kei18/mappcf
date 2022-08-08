module Solver

export Effect, planner1, Failure

import Base: @kwdef, length, isempty
import Base.Iterators: product
import Printf: @printf, @sprintf
import ..MAPPFD:
    Graph,
    Path,
    Paths,
    Crash,
    Config,
    Instance,
    SeqInstance,
    SyncInstance,
    SeqCrash,
    SyncCrash,
    Plan,
    Solution,
    get_correct_crashed_agents,
    get_in_range,
    Deadline,
    generate_deadline,
    is_expired,
    elapsed_sec,
    gen_h_func,
    gen_h_func_wellformed,
    is_no_more_crash,
    verbose,
    MAPF,
    OTIMAPP
import ..MAPPFD.Pathfinding: timed_pathfinding, basic_pathfinding, get_distance_table
import ..MAPPFD.OTIMAPP: FragmentTable, potential_deadlock_exists
import QuickHeaps: FastBinaryHeap, FastForwardOrdering

abstract type Effect end
@kwdef struct Event
    crash::Crash
    effect::Effect
    f::Real = 0
end

@kwdef struct SyncEffect <: Effect
    plan_id::Int
    who::Int
    loc::Int
    when::Int = 1
end

@kwdef struct SeqEffect <: Effect
    plan_id::Int
    who::Int
    loc::Int
    when::Int = 1
end

Base.show(io::IO, e::SyncEffect) = print(
    io,
    "SyncEffect(who=$(e.who), loc=$(e.loc), when=$(e.when), plan_id=$(e.plan_id))",
)
Base.show(io::IO, e::SeqEffect) =
    print(io, "SeqEffect(who=$(e.who), loc=$(e.loc), when=$(e.when), plan_id=$(e.plan_id))")

@enum Failure begin
    FAILURE_OTHERS
    FAILURE_TIMEOUT
    FAILURE_NO_INITIAL_SOLUTION
    FAILURE_NO_BACKUP_PATH
    FAILURE_TIMEOUT_INITIAL_SOLUTION
end

include("./utils.jl")
include("./event_queue.jl")
include("./planner1.jl")
include("./cbs.jl")

end
