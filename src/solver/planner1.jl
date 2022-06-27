function planner1(
    ins::Instance,
    ;
    multi_agent_path_planner::Function = isa(ins, SyncInstance) ? RPP : SeqRPP,
    VERBOSE::Int = 0,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    h_func = gen_h_func(ins),
    search_style::String = "WHEN",
    event_queue_func = gen_event_queue_func(ins, search_style, h_func),
    runtime_profile::Dict{Symbol,Real} = Dict{Symbol,Real}(),
    kwargs...,
)::Union{Failure,Solution}
    # get initial solution
    runtime_profile[:elapsed_initial_paths] = @elapsed begin
        solution = get_initial_solution(
            ins,
            multi_agent_path_planner;
            deadline = deadline,
            h_func = h_func,
            VERBOSE = VERBOSE,
            kwargs...,
        )
    end
    if isnothing(solution)
        verbose(VERBOSE, 1, deadline, "failed to find initial solution")
        return FAILURE_NO_INITIAL_SOLUTION
    end
    verbose(VERBOSE, 1, deadline, "initial paths are found")

    runtime_profile[:elapsed_setup_event_queue] = @elapsed begin
        # setup event queue
        U = EventQueue(f = event_queue_func)
        # identify intersections
        setup_initial_unresolved_events!(ins, solution, U)
    end
    verbose(VERBOSE, 1, deadline, "initial unresolved events: $(length(U))")
    verbose(VERBOSE, 1, deadline, "start resolving events with $(search_style)-style")

    runtime_profile[:elapsed_find_backup_plan] = 0
    runtime_profile[:elapsed_identify_new_event] = 0

    # main loop
    loop_cnt = 0

    while !isempty(U)
        loop_cnt += 1
        verbose(
            VERBOSE,
            2,
            deadline,
            @sprintf("resolved: %04d\tunresolved: %04d", loop_cnt, length(U));
            CR = true,
            LF = VERBOSE > 2,
        )

        # check time limit
        if is_expired(deadline)
            VERBOSE > 1 && print("\n")
            verbose(VERBOSE, 1, deadline, "reaching time limit")
            return FAILURE_TIMEOUT
        end

        event = dequeue!(U)
        verbose(VERBOSE, 3, deadline, "resolving event $(event)")
        # avoid duplication & no more crashes
        !is_backup_required(ins, solution, event) && continue

        runtime_profile[:elapsed_find_backup_plan] += @elapsed begin
            # compute backup paths
            backup_plan = find_backup_plan(
                ins,
                solution,
                event;
                deadline = deadline,
                h_func_global = h_func,
                kwargs...,
            )
        end

        # failed to find backup plan
        if isnothing(backup_plan)
            VERBOSE == 2 && print("\n")
            if is_expired(deadline)
                verbose(VERBOSE, 1, deadline, "reaching time limit")
                return FAILURE_TIMEOUT
            else
                verbose(VERBOSE, 1, deadline, "failed to find backup path")
                return FAILURE_NO_BACKUP_PATH
            end
        end

        # append new intersections
        runtime_profile[:elapsed_identify_new_event] = @elapsed begin
            register_new_backup_plan!(solution, event, backup_plan)
            register_new_unresolved_events!(ins, solution, backup_plan, U)
        end
    end

    VERBOSE == 2 && print("\n")
    verbose(VERBOSE, 1, deadline, "found solution")
    return solution
end

function gen_event_queue_func(
    ins::Instance,
    search_style::String,
    h_func::Function,
)::Function

    # default, "WHEN"
    f = (c::Crash, e::Effect, U::EventQueue) -> e.when

    # the following option may cause bugs (I found a corner case)
    # if search_style == "BFS"
    #     f = (e::Effect, , U::EventQueue) -> length(U) + 1
    # elseif search_style == "DFS"  # stuck
    #     f = (e::Event, U::EventQueue) -> -(length(U) + 1)
    # elseif search_style == "COST_TO_GO"
    #     f = (e::Event, U::EventQueue) -> h_func(e.effect.who)(e.effect.loc)
    # elseif search_style == "M_COST_TO_GO"
    #     f = (e::Event, U::EventQueue) -> -h_func(e.effect.who)(e.effect.loc)
    # elseif search_style == "M_WHEN"
    #     f = (e::Event, U::EventQueue) -> -e.effect.when
    # elseif search_style == "WHO"
    #     f = (e::Event, U::EventQueue) -> e.effect.who + e.effect.when / 1000
    # elseif search_style == "WHEN_CRASH" && isa(ins, SyncInstance)
    #     f = (e::Event, U::EventQueue) -> e.crash.when
    # elseif search_style == "M_WHEN_CRASH" && isa(ins, SyncInstance)
    #     f = (e::Event, U::EventQueue) -> -e.crash.when
    # elseif search_style == "CRITICAL_SECTIONS"
    #     f = (e::Event, U::EventQueue) -> get!(U.agents_counts, e.effect.who, 0)
    # elseif search_style == "M_CRITICAL_SECTIONS"
    #     f = (e::Event, U::EventQueue) -> -get!(U.agents_counts, e.effect.who, 0)
    # end
    return f
end

function is_backup_required(ins::Instance, solution::Solution, event::Event)::Bool
    backup_required_plan = solution[event.effect.who][event.effect.plan_id]
    haskey(backup_required_plan.backup, event.crash) && return false

    # # the following is unnecessary, check function "add_event!"
    # is_no_more_crash(ins, backup_required_plan.crashes) && return false

    return true
end

function get_initial_solution(
    ins::Instance,
    multi_agent_path_planner::Function,
    ;
    VERBOSE::Int = 0,
    deadline::Union{Nothing,Deadline} = nothing,
    h_func::Function = gen_h_func(ins),
    kwargs...,
)::Union{Solution,Nothing}
    primary_paths = multi_agent_path_planner(
        ins;
        VERBOSE = VERBOSE - 2,
        deadline = deadline,
        h_func = h_func,
    )
    isnothing(primary_paths) && return nothing
    N = length(primary_paths)
    return map(i -> [Plan(id = 1, who = i, path = primary_paths[i], offset = 1)], 1:N)
end

function register_new_backup_plan!(solution::Solution, event::Event, new_plan::Plan)
    i = event.effect.who
    plan_id = length(solution[i]) + 1
    new_plan.id = plan_id
    push!(solution[i], new_plan)
    solution[i][event.effect.plan_id].backup[event.crash] = plan_id
end


function inconsistent(
    ins::Instance,
    crashes_i::Vector{Crash},
    crashes_j::Vector{Crash},
)::Bool
    # check number of observed crashes
    if !isnothing(ins.max_num_crashes)
        l = length(Set(vcat(map(c -> c.who, crashes_i), map(c -> c.who, crashes_j))))
        l >= ins.max_num_crashes && return true
    end

    # crash for one agent
    any(e -> e[1].who == e[2].who && e[1].loc != e[2].loc, product(crashes_i, crashes_j)) &&
        return true

    return false
end

function setup_initial_unresolved_events!(
    ins::Instance,
    solution::Solution,
    U::EventQueue,
)::Nothing
    N = length(solution)
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
end

# TODO: cache
function register_new_unresolved_events!(
    ins::Instance,
    solution::Solution,
    plan_i::Plan,
    U::EventQueue,
)::Nothing

    N = length(solution)
    i = plan_i.who
    correct_agents, = get_correct_crashed_agents(N, i, plan_i.crashes)

    # storing who uses where and when
    table = Dict{Int,Vector{Tuple{Int,Int,Int}}}()  # who, when, where
    for j in correct_agents, plan_j in solution[j]
        any(c -> c.who == i, plan_j.crashes) && continue  # excluding assumed crashed agents
        for (t_j, v) in enumerate(plan_j.path)
            get!(table, v, Vector{Tuple{Int,Int,Int}}())
            push!(table[v], (j, t_j, plan_j.id))
        end
    end

    for t_i = plan_i.offset+1:length(plan_i.path)
        v = plan_i.path[t_i]
        for (j, t_j, plan_j_id) in get!(table, v, [])
            plan_j = solution[j][plan_j_id]
            inconsistent(ins, plan_i.crashes, plan_j.crashes) && continue
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
end


# =============================================================
# sequential model
# =============================================================

function find_backup_plan(
    ins::SeqInstance,
    solution::Solution,
    event::Event;
    deadline::Union{Nothing,Deadline} = nothing,
    h_func_global::Function = gen_h_func(ins),
    use_aggressive_h_func::Bool = false,
    kwargs...,
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

    @assert(
        isnothing(ins.max_num_crashes) || length(crashes) <= ins.max_num_crashes,
        "no more crash"
    )

    # h-value
    h_func = h_func_global(i)
    if use_aggressive_h_func
        dist_table = get_distance_table(ins.G, g, crashed_locations)
        # not reachable -> failure
        dist_table[s] > length(ins.G) && return nothing
        h_func = (v) -> dist_table[v]
    end


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

    path = basic_pathfinding(
        G = ins.G,
        start = s,
        goal = g,
        invalid = invalid,
        h_func = h_func,
        deadline = deadline,
    )
    isnothing(path) && return nothing
    path = vcat(original_plan_i.path[1:offset-1], path)
    return Plan(who = i, path = path, offset = offset, crashes = crashes)
end

function add_event!(
    U::EventQueue,
    ins::SeqInstance;
    v::Int,
    plan_i::Plan,
    plan_j::Plan,
    t_j::Int,
    t_i::Int,
)::Nothing

    i = plan_i.who
    j = plan_j.who
    @assert(i != j, "add_event!")
    c_i = SeqCrash(who = i, loc = v)
    c_j = SeqCrash(who = j, loc = v)
    if t_i > 1 && !haskey(plan_i.backup, c_j) && can_add_crash(ins, plan_i.crashes)
        e_i = SeqEffect(who = i, when = t_i, loc = v, plan_id = plan_i.id)
        enqueue!(U, Event(crash = c_j, effect = e_i))
    end
    if t_j > 1 && !haskey(plan_j.backup, c_i) && can_add_crash(ins, plan_j.crashes)
        e_j = SeqEffect(who = j, when = t_j, loc = v, plan_id = plan_j.id)
        enqueue!(U, Event(crash = c_i, effect = e_j))
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
    ;
    deadline::Union{Nothing,Deadline} = nothing,
    timestep_limit::Union{Nothing,Int} = nothing,
    h_func_global::Function = (v) -> 0,
    use_aggressive_h_func::Bool = false,
    avoid_duplicates_backup::Bool = false,
    avoid_duplicates_backup_weight::Real = 0.01,
    kwargs...,
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

    @assert(
        isnothing(ins.max_num_crashes) || length(crashes) <= ins.max_num_crashes,
        "no more crash"
    )

    used_cnt_table = fill(0, length(ins.G))
    if avoid_duplicates_backup
        for j in correct_agents, plan_j in solution[j]
            if length(plan_j.path) < offset
                used_cnt_table[last(plan_j.path)] += 1
            else
                foreach(v -> used_cnt_table[v] += 1, plan_j.path)
            end
        end
    end

    # h-value
    h_func = begin
        if use_aggressive_h_func
            dist_table = get_distance_table(ins.G, g, crashed_locations)
            # not reachable -> failure
            dist_table[s] > length(ins.G) && return nothing
            (v) -> dist_table[v] + used_cnt_table[v] * avoid_duplicates_backup_weight
        else
            (v) -> h_func_global(i)(v) + used_cnt_table[v] * avoid_duplicates_backup_weight
        end
    end


    invalid =
        (S_from, S_to) -> begin
            v_i_from = S_from.v
            v_i_to = S_to.v
            t = S_to.t + offset - 1
            # check timestep limit
            !isnothing(timestep_limit) && t > timestep_limit && return true
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

    path = timed_pathfinding(;
        G = ins.G,
        start = s,
        check_goal = (S) -> S.v == g,
        invalid = invalid,
        deadline = deadline,
        h_func = h_func,
    )
    isnothing(path) && return nothing
    path = vcat(original_plan_i.path[1:offset-1], path)
    return Plan(who = i, path = path, offset = offset, crashes = crashes)
end

function add_event!(
    U::EventQueue,
    ins::SyncInstance;
    v::Int,
    plan_i::Plan,
    plan_j::Plan,
    t_i::Int,
    t_j::Int,
)::Nothing

    i = plan_i.who
    j = plan_j.who
    @assert(i != j, "add_event!")
    @assert(t_i != t_j, "collision occurs")
    if t_i < t_j && can_add_crash(ins, plan_j.crashes)
        c_i = SyncCrash(who = i, loc = v, when = t_i)
        e_j = SyncEffect(who = j, when = t_j, loc = v, plan_id = plan_j.id)
        enqueue!(U, Event(crash = c_i, effect = e_j, f = U.f(c_i, e_j, U)))
    elseif t_j < t_i && can_add_crash(ins, plan_i.crashes)
        c_j = SyncCrash(who = j, loc = v, when = t_j)
        e_i = SyncEffect(who = i, when = t_i, loc = v, plan_id = plan_i.id)
        enqueue!(U, Event(crash = c_j, effect = e_i, f = U.f(c_j, e_i, U)))
    end
    nothing
end
