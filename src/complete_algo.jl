# global failure detector
function planner2(ins::SyncInstance; VERBOSE::Int = 0)::Solution
    return flatten_recursive_solution(planner2(ins.G, ins.starts, ins.goals))
end

function planner2(
    G::Graph,
    starts::Config,
    goals::Config,
    crashes::Vector{Crash} = Vector{Crash}(),
    offset::Int = 1,
    parent_constrations::Vector{Effect} = Vector{Effect}(),
)
    constraints = copy(parent_constrations)
    @label START_PLANNING
    # compute collision-free paths
    paths = astar_operator_decomposition(G, starts, goals, crashes, constraints, offset)
    isnothing(paths) && return nothing

    # identify critical sections
    U = get_new_unresolved_events(paths, offset)
    # compute backup paths
    backups = Dict()
    for event in U
        # recursive call
        backups[event.crash] = planner2(
            G,
            map(path -> get_in_range(path, event.crash.when - offset + 1), paths),
            goals,
            vcat(crashes, event.crash),
            event.crash.when,
            constraints,
        )
        # failed to find backup path
        if isnothing(backups[event.crash])
            # update constrains
            push!(constraints, event.effect)
            # re-planning
            @goto START_PLANNING
        end
    end
    return (paths = paths, offset = offset, backups = backups)
end

function flatten_recursive_solution(recursive_solution)::Union{Nothing,Solution}
    isnothing(recursive_solution) && return nothing

    N = length(recursive_solution.paths)
    solution = map(i -> Vector{Plan}(), 1:N)

    f!(S, parent_id::Union{Nothing,Int} = nothing) = begin
        plan_id = length(solution[1]) + 1
        offset = S.offset
        for i = 1:N
            parent_path =
                isnothing(parent_id) ? Path() : solution[i][parent_id].path[1:offset-1]
            plan = Plan(
                id = plan_id,
                who = i,
                path = vcat(parent_path, S.paths[i]),
                offset = offset,
            )
            push!(solution[i], plan)
        end
        for (crash, backup_plan) in S.backups
            children_id = f!(backup_plan, plan_id)
            foreach(i -> solution[i][plan_id].backup[crash] = children_id, 1:N)
        end
        return plan_id
    end

    f!(recursive_solution)
    return solution
end

function get_new_unresolved_events(paths::Paths, offset::Int = 1)::Vector{Event}
    U = Vector{Event}()
    table = Dict()   # vertex => [ (who, when) ]
    for (i, path) in enumerate(paths)
        for t_i = 1:length(path)
            loc = path[t_i]
            # new critical section is found
            for (j, t_j) in get!(table, loc, [])
                j == i && continue
                @assert(t_i != t_j, "identify critical sections")
                if t_j < t_i
                    c_j = SyncCrash(when = t_j + offset - 1, who = j, loc = loc)
                    e_i = SyncEffect(when = t_i + offset - 1, who = i, loc = loc)
                    push!(U, Event(crash = c_j, effect = e_i))
                elseif t_i < t_j
                    c_i = SyncCrash(when = t_i + offset - 1, who = i, loc = loc)
                    e_j = SyncEffect(when = t_j + offset - 1, who = j, loc = loc)
                    push!(U, Event(crash = c_i, effect = e_j))
                end
            end
            # register new entry
            push!(table[loc], (i, t_i))
        end
    end
    return U
end

function astar_operator_decomposition(
    G::Graph,
    starts::Config,
    goals::Config,
    crashes::Vector{Crash},
    constraints::Vector{Effect},
    offset::Int;
    dist_tables::Vector{Vector{Int}} = MAPF.get_distance_tables(G, goals),
)::Union{Nothing,Paths}

    N = length(starts)
    correct_agents, crashed_agents = get_correct_crashed_agents(N, crashes)
    correct_goals = map(i -> goals[i], correct_agents)

    invalid =
        (S_from::MAPF.AODNode, S_to::MAPF.AODNode) -> begin
            MAPF.invalidAOD(S_from, S_to) && return true
            i = S_from.next
            v = S_to.Q[i]
            t = S_to.timestep

            # check goals
            i in correct_agents && v != goals[i] && v in correct_goals && return true

            # check constraints
            any(c -> c.who == i && c.loc == v && c.when - offset == t, constraints) &&
                return true

            # otherwise
            return false
        end

    get_node_neighbors =
        (S) -> begin
            i = S.next
            j = mod1(S.next + 1, N)
            v_from = S.Q[i]
            timestep = (j == 1) ? S.timestep + 1 : S.timestep
            return map(
                v_to -> MAPF.AODNode(
                    Q = map(k -> k == i ? v_to : S.Q[k], 1:N),
                    Q_prev = (j == 1) ? copy(S.Q) : copy(S.Q_prev),
                    next = j,
                    g = (v_to == goals[i]) ? S.g : S.g + 1,  # minimize time not at goal
                    h = S.h - dist_tables[i][v_from] + dist_tables[i][v_to],
                    parent = S,
                    timestep = timestep,
                ),
                i in crashed_agents ? [v_from] : vcat(get_neighbors(G, v_from), v_from),
            )
        end

    return search(
        initial_node = MAPF.get_initial_AODNode(starts, dist_tables),
        invalid = invalid,
        check_goal = (S) -> all(i -> S.Q[i] == goals[i], correct_agents) && S.next == 1,
        get_node_neighbors = get_node_neighbors,
        get_node_id = (S) -> string(S),
        get_node_score = (S) -> S.f,
        backtrack = MAPF.backtrackAOD,
    )
end
