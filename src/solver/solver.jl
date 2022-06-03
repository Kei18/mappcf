module Solver

export Effect, planner1, planner2

import Base: @kwdef
import Base.Iterators: product
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
    gen_h_func
import ..MAPPFD.Pathfinding: timed_pathfinding, basic_pathfinding
import ..MAPPFD.MAPF: astar_operator_decomposition
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

include("./utils.jl")
include("./planner1.jl")
include("./planner2.jl")

end
