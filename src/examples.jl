function generate_sample_graph1()::Graph
    G = map(i -> Vertex(id = i), 1:5)
    G[1].pos = [0, 0]
    G[2].pos = [1, 0]
    G[3].pos = [2, 0]
    G[4].pos = [0.5, 1]
    G[5].pos = [0.5, -1]
    add_edges!(G, (1, 2), (2, 3), (1, 4), (2, 4), (1, 5), (2, 5))
    return G
end

function generate_sample_graph2()::Graph
    G = generate_grid(5, 5; obstacle_locs = [21, 23, 24, 25, 18, 20, 8])
    remove_edges!(G, (2, 7), (4, 9), (9, 10))
    return G
end

function generate_sample_graph3()::Graph
    G = generate_grid(5, 2, obstacle_locs = [1, 4, 5])
    remove_edges!(G, (2, 7), (3, 8), (2, 3))
    add_edges!(G, (2, 8), (3, 9), (3, 8))
    return G
end

function generate_sample_graph4()::Graph
    G = generate_grid(3, 3, obstacle_locs = [1, 3, 7, 9])
    add_edges!(G, (2, 4), (2, 6), (8, 6))
    return G
end

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
