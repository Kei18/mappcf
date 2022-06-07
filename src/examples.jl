function astar_operator_decomposition(
    G::Graph,
    starts::Config,
    goals::Config,
    crashes::Vector{Crash},
    constraints::Vector{Effect},
    offset::Int;
    h_func = gen_h_func(G, goals),
    deadline::Union{Nothing,Deadline} = nothing,
    timestep_limit::Union{Nothing,Int} = nothing,
    VERBOSE::Int = 0,
    kwargs...,
)::Union{Nothing,Paths}

    N = length(starts)
    correct_agents, crashed_agents = get_correct_crashed_agents(N, crashes)

    # check constraints
    invalid = MAPF.gen_invalid_AOD(
        goals;
        correct_agents = correct_agents,
        timestep_limit = timestep_limit,
        additional_constraints = (S_from::MAPF.AODNode, S_to::MAPF.AODNode) -> begin
            i = S_from.next
            v = S_to.Q[i]
            t = S_to.timestep
            return any(c -> c.who == i && c.loc == v && c.when - offset == t, constraints)
        end,
    )

    return search(
        initial_node = MAPF.get_initial_AODNode(starts, h_func),
        invalid = invalid,
        check_goal = (S) -> all(i -> S.Q[i] == goals[i], correct_agents) && S.next == 1,
        get_node_neighbors = MAPF.gen_get_node_neighbors_AOD(
            G,
            goals,
            h_func,
            crashed_agents,
        ),
        get_node_id = (S) -> string(S),
        get_node_score = (S) -> S.f,
        backtrack = MAPF.backtrack_AOD,
        deadline = deadline,
    )
end

function get_path_length(plan::Plan)::Int
    return get_path_length(plan.path)
end

function get_traveling_time(plan::Plan)::Int
    return get_traveling_time(plan.path)
end

function get_scores(solution::Union{Nothing,Solution})::Dict{Symbol,Int}

    primary_sum_of_path_length = 0
    primary_max_path_length = 0
    primary_sum_of_traveling_time = 0
    primary_max_traveling_time = 0

    worst_sum_of_path_length = 0
    worst_max_path_length = 0
    worst_sum_of_traveling_time = 0
    worst_max_traveling_time = 0

    if !isnothing(solution)
        for plans in solution
            # primary path
            primary_plan = first(plans)
            path_length = get_path_length(primary_plan)
            traveling_time = get_traveling_time(primary_plan)
            primary_sum_of_path_length += path_length
            primary_max_path_length = max(primary_max_path_length, path_length)
            primary_sum_of_traveling_time += traveling_time
            primary_max_traveling_time = max(primary_max_traveling_time, traveling_time)

            # worst case
            arr_path_length = map(get_path_length, plans)
            arr_traveling_time = map(get_traveling_time, plans)
            path_length = maximum(arr_path_length)
            traveling_time = maximum(arr_traveling_time)
            worst_sum_of_path_length += path_length
            worst_max_path_length = max(worst_max_path_length, path_length)
            worst_sum_of_traveling_time += traveling_time
            worst_max_traveling_time = max(worst_max_traveling_time, traveling_time)
        end
    end

    return Dict(
        :worst_max_path_length => worst_max_path_length,
        :worst_sum_of_path_length => worst_sum_of_path_length,
        :worst_max_traveling_time => worst_max_traveling_time,
        :worst_sum_of_traveling_time => worst_sum_of_traveling_time,
        #
        :primary_max_path_length => primary_max_path_length,
        :primary_sum_of_path_length => primary_sum_of_path_length,
        :primary_max_traveling_time => primary_max_traveling_time,
        :primary_sum_of_traveling_time => primary_sum_of_traveling_time,
    )
end

function get_scores(ins::Instance, solution::Union{Nothing,Solution})::Dict{Symbol,Int}
    N = length(ins.starts)
    tables = get_distance_tables(ins.G, ins.goals)
    arr_shortest_path_length = map(i -> tables[i][ins.starts[i]], 1:N)

    return merge(
        Dict(
            :num_vertices => get_num_vertices(ins.G),
            :sum_of_shortest_path_lengths => sum(arr_shortest_path_length),
            :max_shortest_path_lengths => maximum(arr_shortest_path_length),
        ),
        get_scores(solution),
    )
end
