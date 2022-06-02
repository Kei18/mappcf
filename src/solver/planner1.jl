function planner1(
    ins::Instance,
    multi_agent_path_planner::Function,  # (Instance) -> Paths
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
    correct_agents, = get_correct_crashed_agents(N, i, plan_i.crashes)

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
    correct_agents, = get_correct_crashed_agents(N, i, crashes)
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
    correct_agents, = get_correct_crashed_agents(N, i, crashes)
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
