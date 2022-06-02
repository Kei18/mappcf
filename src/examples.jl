function generate_random_instance_grid(;
    N_min::Int = 5,
    N_max::Int = 10,
    N::Int = rand(N_min:N_max),
    width::Int = 8,
    height::Int = 8,
    occupancy_rate::Real = 0.1,
)::Tuple{Graph,Config,Config}  # graph, starts, goals

    G = generate_random_grid(width, height; occupancy_rate = occupancy_rate)
    vertex_ids = filter(k -> !isempty(get_neighbors(G, k)), 1:length(G))
    @assert(N < 2 * length(vertex_ids), "too many agents on a graph")
    random_indexes = randperm(length(vertex_ids))
    starts = vertex_ids[random_indexes[1:N]]
    goals = vertex_ids[random_indexes[N+1:2N]]
    return (G, starts, goals)
end

function generate_random_sync_instance_grid(; kwargs...)::SyncInstance
    return SyncInstance(generate_random_instance_grid(; kwargs...)...)
end

function generate_random_seq_instance_grid(; kwargs...)::SeqInstance
    return SeqInstance(generate_random_instance_grid(; kwargs...)...)
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
