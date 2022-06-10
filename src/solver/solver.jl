module Solver

export Effect, planner1, planner2, Failure

import Base: @kwdef
import Base.Iterators: product
import Printf: @printf
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
    gen_h_func,
    is_no_more_crash,
    MAPF
import ..MAPPFD.Pathfinding: timed_pathfinding, basic_pathfinding, get_distance_table
import ..MAPPFD.OTIMAPP:
    FragmentTable,
    potential_deadlock_exists,
    prioritized_planning as seq_prioritized_planning

abstract type Effect end
@kwdef struct Event
    crash::Crash
    effect::Effect
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
    FAILURE
    FAILURE_TIMEOUT
    FAILURE_NO_INITIAL_SOLUTION
    FAILURE_NO_BACKUP_PATH
end

include("./utils.jl")
include("./planner1.jl")
include("./planner2.jl")

end
