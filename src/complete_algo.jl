# global failure detector
function planner2(ins::SyncInstance; VERBOSE::Int = 0)::Solution
    return flatten_recursive_solution(planner2(ins.G, ins.starts, ins.goals))
end

@kwdef mutable struct RecursiveSolution
    paths::Paths
    offset::Int
    backup::Dict{Crash,RecursiveSolution}
end

function planner2(
    G::Graph,
    starts::Config,
    goals::Config,
    crashes::Vector{Crash} = Vector{Crash}(),
    offset::Int = 1,
    parent_constrations::Vector{Effect} = Vector{Effect}(),
)::Union{Nothing,RecursiveSolution}
    constraints = copy(parent_constrations)
    @label START_PLANNING
    # compute collision-free paths
    paths = astar_operator_decomposition(G, starts, goals, crashes, constraints, offset)
    isnothing(paths) && return nothing

    # identify critical sections
    U = get_new_unresolved_events(paths, offset)
    # compute backup paths
    backup = Dict()
    for event in U
        # recursive call
        backup[event.crash] = planner2(
            G,
            map(path -> get_in_range(path, event.crash.when - offset + 1), paths),
            goals,
            vcat(crashes, event.crash),
            event.crash.when,
            constraints,
        )
        # failed to find backup path
        if isnothing(backup[event.crash])
            # update constrains
            push!(constraints, event.effect)
            # re-planning
            @goto START_PLANNING
        end
    end
    return RecursiveSolution(paths = paths, offset = offset, backup = backup)
end

function flatten_recursive_solution(
    recursive_solution::RecursiveSolution,
)::Union{Nothing,Solution}
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
        for (crash, backup_plan) in S.backup
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
    for (i, path) in enumerate(paths), t_i = 1:length(path)
        v = path[t_i]
        # new critical section is found
        for (j, t_j) in get!(table, v, [])
            j == i && continue
            e = get_sync_event(; v = v, i = i, j = j, t_i = t_i, t_j = t_j, offset = offset)
            push!(U, e)
        end
        push!(table[v], (i, t_i))
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

    # check constraints
    invalid = MAPF.gen_invalid_AOD(
        goals;
        correct_agents = correct_agents,
        additional_constraints = (S_from::MAPF.AODNode, S_to::MAPF.AODNode) -> begin
            i = S_from.next
            v = S_to.Q[i]
            t = S_to.timestep
            return any(c -> c.who == i && c.loc == v && c.when - offset == t, constraints)
        end,
    )

    return search(
        initial_node = MAPF.get_initial_AODNode(starts, dist_tables),
        invalid = invalid,
        check_goal = (S) -> all(i -> S.Q[i] == goals[i], correct_agents) && S.next == 1,
        get_node_neighbors = MAPF.gen_get_node_neighbors_AOD(
            G,
            goals,
            dist_tables,
            crashed_agents,
        ),
        get_node_id = (S) -> string(S),
        get_node_score = (S) -> S.f,
        backtrack = MAPF.backtrack_AOD,
    )
end
