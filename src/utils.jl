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

function generate_random_instance(;
    N::Int = rand(3:8),
    num_vertices::Int = 30,
    prob::Float64 = 0.2,
)::Tuple{Graph,Config,Config}  # graph, starts, goals

    G = generate_random_graph(num_vertices, prob)
    @assert(N < length(G), "too many agents on a graph")
    starts = randperm(length(G))[1:N]
    goals = randperm(length(G))[1:N]
    return (G, starts, goals)
end
