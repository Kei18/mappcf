@kwdef mutable struct Vertex
    id::Int  # unique id
    pos::Vector{Real} = rand(2)  # assuming 2d
    neigh::Vector{Int} = [] # indexes
end
Graph = Vector{Vertex}
Config = Vector{Int}  # vertex indexes
Path = Vector{Int}
Paths = Vector{Path}

function get(G::Graph, loc::Int)
    return G[loc]
end

function get_neighbors(G::Graph, loc::Int)::Vector{Int}
    return G[loc].neigh
end

function generate_grid(width::Int = 5, height::Int = 3; obstacle_locs = [])::Graph
    G = Graph()
    for j = 1:height, i = 1:width
        neigh = []
        id = length(G) + 1
        i > 1 && push!(neigh, id - 1)
        i < width && push!(neigh, id + 1)
        j > 1 && push!(neigh, id - width)
        j < height && push!(neigh, id + width)
        push!(G, Vertex(id = id, pos = [i / width, j / height], neigh = neigh))
    end

    for v_id in obstacle_locs
        for u_id in get_neighbors(G, v_id)
            u = MAPPFD.get(G, u_id)
            u.neigh = filter(w_id -> w_id != v_id, u.neigh)
        end
        MAPPFD.get(G, v_id).neigh = []
    end

    return G
end

function generate_grid(width::Int = 5, height::Int = 3, args...)::Graph
    generate_grid(width, height; obstacle_locs = args)
end

function add_edges!(G::Graph, edges...)::Nothing
    for (u, v) in edges
        push!(get(G, u).neigh, v)
        push!(get(G, v).neigh, u)
    end
end

function remove_edges!(G::Graph, edges...)::Nothing
    for (u, v) in edges
        filter!(w -> w != v, get(G, u).neigh)
        filter!(w -> w != u, get(G, v).neigh)
    end
end

function generate_random_grid(
    width::Int = 8,
    height::Int = 8;
    occupancy_rate::Float64 = 0.2,
)::Graph
    l = width * height
    return generate_grid(
        width,
        height;
        obstacle_locs = randperm(l)[1:round(Int, l * occupancy_rate)],
    )
end

function generate_random_graph(num_vertices::Int = 30, prob::Float64 = 0.2)::Graph
    G = map(k -> Vertex(id = k), 1:num_vertices)
    for i = 1:num_vertices, j = 1:i
        rand() > prob && continue
        push!(get(G, i).neigh, j)
        push!(get(G, j).neigh, i)
    end
    return G
end

function generate_sample_graph1()::Graph
    # setup undirected graph
    G = map(i -> Vertex(id = i), 1:5)

    G[1].pos = [0, 0]
    G[2].pos = [1, 0]
    G[3].pos = [2, 0]
    G[4].pos = [0.5, 1]
    G[5].pos = [0.5, -1]

    E = [(1, 2), (2, 3), (1, 4), (2, 4), (1, 5), (2, 5)]
    for (i, j) in E
        push!(G[i].neigh, j)
        push!(G[j].neigh, i)
    end

    return G
end

function generate_sample_graph2()::Graph
    G = generate_grid(5, 5, 21, 23, 24, 25, 18, 20, 8)
    remove_edges!(G, (2, 7), (4, 9), (9, 10))
    return G
end
