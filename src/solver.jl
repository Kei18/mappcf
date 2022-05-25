abstract type Crash end
abstract type Effect end

@kwdef struct Event
    crash::Crash
    effect::Effect
end

@kwdef struct SyncCrash <: Crash
    who::Int
    loc::Int
    when::Int = 1
end

@kwdef struct SeqCrash <: Crash
    who::Int
    loc::Int
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

Base.show(io::IO, c::SyncCrash) =
    print(io, "SyncCrash(who=$(c.who), loc=$(c.loc), when=$(c.when))")
Base.show(io::IO, c::SeqCrash) = print(io, "SyncCrash(who=$(c.who), loc=$(c.loc))")
Base.show(io::IO, e::SyncEffect) = print(
    io,
    "SyncEffect(who=$(e.who), loc=$(e.loc), when=$(e.when), plan_id=$(e.plan_id))",
)
Base.show(io::IO, e::SeqEffect) =
    print(io, "SeqEffect(who=$(e.who), loc=$(e.loc), when=$(e.when), plan_id=$(e.plan_id))")

@kwdef mutable struct Plan
    id::Int = 1
    who::Int
    path::Path
    offset::Int
    backup::Dict{Crash,Int} = Dict()  # detecting crash -> next plan id
    crashes::Vector{Crash} = []
end
Solution = Vector{Vector{Plan}}

function planner1(
    ins::Instance,
    multi_agent_path_planner::Function,  # (Instance) -> paths
    ;
    VERBOSE::Int = 0,
)::Union{Nothing,Solution}
    # get initial solution
    solution = get_initial_solution(ins, multi_agent_path_planner)
    isnothing(solution) && return nothing

    # identify intersections
    U = get_initial_unresolved_events(ins, solution)

    # main loop
    while !isempty(U)
        event = popfirst!(U)
        # compute backup paths
        backup_plan = find_backup_plan(ins, solution, event)
        isnothing(backup_plan) && return nothing
        register!(solution, event, backup_plan)
        # append new intersections
        U = vcat(U, get_new_unresolved_events(ins, solution, backup_plan))
    end
    return solution
end

function get_initial_solution(
    ins::Instance,
    multi_agent_path_planner::Function,
)::Union{Solution,Nothing}

    primary_paths = multi_agent_path_planner(ins)
    isnothing(primary_paths) && return nothing
    N = length(primary_paths)
    return map(i -> [Plan(id = 1, who = i, path = primary_paths[i], offset = 1)], 1:N)
end

function get_correct_crashed_agents(
    N::Int,
    crashes::Vector{Crash},
)::@NamedTuple {correct_agents::Vector{Int}, crashed_agents::Vector{Int}}
    crashed_agents = map(c -> c.who, crashes)
    correct_agents = filter(i -> all(j -> j != i, crashed_agents), 1:N)
    return (correct_agents = correct_agents, crashed_agents = crashed_agents)
end

function get_correct_crashed_agents(
    N::Int,
    i::Int,
    crashes::Vector{Crash},
)::@NamedTuple {correct_agents::Vector{Int}, crashed_agents::Vector{Int}}
    (correct_agents, crashed_agents) = get_correct_crashed_agents(N, crashes)
    filter!(j -> j != i, correct_agents)
    return (correct_agents = correct_agents, crashed_agents = crashed_agents)
end


function register!(solution::Solution, event::Event, new_plan::Plan)
    i = event.effect.who
    plan_id = length(solution[i]) + 1
    new_plan.id = plan_id
    push!(solution[i], new_plan)
    solution[i][event.effect.plan_id].backup[event.crash] = plan_id
end


function inconsistent(crashes_i::Vector{Crash}, crashes_j::Vector{Crash})::Bool
    return any(
        e -> e[1].who == e[2].who && e[1].loc != e[2].loc,
        product(crashes_i, crashes_j),
    )
end

function get_initial_unresolved_events(ins::Instance, solution::Solution)::Vector{Event}
    N = length(solution)
    U = Vector{Event}()
    # storing who uses where and when
    table = Dict()
    for i = 1:N, (t_i, v) in enumerate(solution[i][1].path)
        for (j, t_j) in get!(table, v, [])
            j == i && continue
            add_event!(
                U,
                ins;
                plan_i = solution[i][1],
                plan_j = solution[j][1],
                t_i = t_i,
                t_j = t_j,
                v = v,
            )
        end
        push!(table[v], (who = i, when = t_i))
    end
    return U
end

function get_new_unresolved_events(
    ins::Instance,
    solution::Solution,
    plan_i::Plan,
)::Vector{Event}

    N = length(solution)
    i = plan_i.who
    (correct_agents, crashed_agents) = get_correct_crashed_agents(N, i, plan_i.crashes)

    # storing who uses where and when
    table = Dict()
    for j in correct_agents, plan_j in solution[j]
        any(c -> c.who == i, plan_j.crashes) && continue  # excluding assumed crashed agents
        for (t_j, v) in enumerate(plan_j.path)
            get!(table, v, [])
            push!(table[v], (who = j, when = t_j, plan_id = plan_j.id))
        end
    end

    U = Vector{Event}()
    for t_i = plan_i.offset+1:length(plan_i.path)
        v = plan_i.path[t_i]
        for (j, t_j, plan_j_id) in get!(table, v, [])
            plan_j = solution[j][plan_j_id]
            inconsistent(plan_i.crashes, plan_j.crashes) && continue
            add_event!(
                U,
                ins;
                plan_i = plan_i,
                plan_j = plan_j,
                t_i = t_i,
                t_j = t_j,
                v = v,
            )
        end
    end

    return U
end


# =============================================================
# sequential model
# =============================================================

function find_backup_plan(
    ins::SeqInstance,
    solution::Solution,
    event::Event,
)::Union{Nothing,Plan}
    N = length(solution)
    # who
    i = event.effect.who
    # when
    offset = event.effect.when - 1
    # which plan
    original_plan_i = solution[i][event.effect.plan_id]
    # new start & goal
    s = original_plan_i.path[offset]
    g = ins.goals[i]
    # crashes must be handled
    crashes = vcat(original_plan_i.crashes, event.crash)
    (correct_agents, crashed_agents) = get_correct_crashed_agents(N, i, crashes)
    correct_agents_goals = map(j -> ins.goals[j], correct_agents)
    crashed_locations = map(c -> c.loc, crashes)

    table = FragmentTable()
    for j in correct_agents, plan_j in solution[j]
        register!(table, j, plan_j.path)
    end

    invalid =
        (S_from, S_to) -> begin
            # avoid terminal deadlocks
            S_to.v in correct_agents_goals && return true
            # avoid cyclic deadlocks
            potential_deadlock_exists(S_from.v, S_to.v, table) && return true
            # avoid crashed locations
            S_to.v in crashed_locations && return true
            return false
        end

    path = basic_pathfinding(G = ins.G, start = s, goal = g, invalid = invalid)
    isnothing(path) && return nothing
    path = vcat(original_plan_i.path[1:offset-1], path)
    return Plan(who = i, path = path, offset = offset, crashes = crashes)
end


function add_event!(
    U::Vector{Event},
    ins::SeqInstance;
    v::Int,
    plan_i::Plan,
    plan_j::Plan,
    t_j::Int,
    t_i::Int,
)::Nothing

    i = plan_i.who
    j = plan_j.who
    c_i = SeqCrash(who = i, loc = v)
    c_j = SeqCrash(who = j, loc = v)
    if t_i > 1 && !haskey(plan_i.backup, c_j)
        e_i = SeqEffect(who = i, when = t_i, loc = v, plan_id = plan_i.id)
        push!(U, Event(crash = c_j, effect = e_i))
    end
    if t_j > 1 && !haskey(plan_j.backup, c_i)
        e_j = SeqEffect(who = j, when = t_j, loc = v, plan_id = plan_j.id)
        push!(U, Event(crash = c_i, effect = e_j))
    end
    nothing
end

# =============================================================
# synchronous model
# =============================================================
function find_backup_plan(
    ins::SyncInstance,
    solution::Solution,
    event::Event,
)::Union{Nothing,Plan}

    N = length(solution)
    # who
    i = event.effect.who
    # when
    offset = event.effect.when - 1
    # which plan
    original_plan_i = solution[i][event.effect.plan_id]
    # new start & goal
    s = original_plan_i.path[offset]
    # crashes must be handled
    crashes = vcat(original_plan_i.crashes, event.crash)
    (correct_agents, crashed_agents) = get_correct_crashed_agents(N, i, crashes)
    correct_agents_goals = map(j -> ins.goals[j], correct_agents)
    crashed_locations = map(c -> c.loc, crashes)

    invalid =
        (S_from, S_to) -> begin
            v_i_from = S_from.v
            v_i_to = S_to.v
            t = S_to.t + offset - 1
            # avoid crashed agents
            v_i_to in crashed_locations && return true
            # avoid others' goals
            v_i_to in correct_agents_goals && return true
            # avoid collisions
            for j in correct_agents, plan_j in solution[j]
                any(c -> c.who == i, plan_j.crashes) && continue
                v_j_from = get_in_range(plan_j.path, t - 1)
                v_j_to = get_in_range(plan_j.path, t)
                (v_i_to == v_j_to || (v_i_to == v_j_from && v_i_from == v_j_to)) &&
                    return true
            end
            return false
        end

    path = timed_pathfinding(
        G = ins.G,
        start = s,
        check_goal = (S) -> S.v == ins.goals[i],
        invalid = invalid,
    )
    isnothing(path) && return nothing
    path = vcat(original_plan_i.path[1:offset-1], path)
    return Plan(who = i, path = path, offset = offset, crashes = crashes)
end

function add_event!(
    U::Vector{Event},
    ins::SyncInstance;
    v::Int,
    plan_i::Plan,
    plan_j::Plan,
    t_j::Int,
    t_i::Int,
)::Nothing

    i = plan_i.who
    j = plan_j.who
    @assert(t_i != t_j, "collision occurs")

    if t_i < t_j
        c_i = SyncCrash(who = i, loc = v, when = t_i)
        e_j = SyncEffect(who = j, when = t_j, loc = v, plan_id = plan_j.id)
        push!(U, Event(crash = c_i, effect = e_j))
    else  # t_j < t_i
        c_j = SyncCrash(who = j, loc = v, when = t_j)
        e_i = SyncEffect(who = i, when = t_i, loc = v, plan_id = plan_i.id)
        push!(U, Event(crash = c_j, effect = e_i))
    end
    nothing
end
