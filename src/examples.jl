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
