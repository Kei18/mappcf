@kwdef mutable struct Vertex
    id::Int  # unique id
    pos::Vector{Real} = rand(2)  # assuming 2d
    neigh::Vector{Int} = Vector{Int}() # indexes
end
Graph = Vector{Vertex}
Config = Vector{Int}  # vertex indexes, all agents
Path = Vector{Int}  # path for one agent
Paths = Vector{Path}

function get(G::Graph, loc::Int)
    return G[loc]
end

function get_neighbors(G::Graph, loc::Int)::Vector{Int}
    return G[loc].neigh
end

function generate_grid(
    width::Int,
    height::Int;
    obstacle_locs::Vector{Int} = Vector{Int}(),
)::Graph
    G = Graph()
    # set vertices and edgers
    for j = 1:height, i = 1:width
        neigh = []
        id = length(G) + 1
        i > 1 && push!(neigh, id - 1)
        i < width && push!(neigh, id + 1)
        j > 1 && push!(neigh, id - width)
        j < height && push!(neigh, id + width)
        push!(G, Vertex(id = id, pos = [i / width, j / height], neigh = neigh))
    end

    # set obstacles
    for v_id in vcat(obstacle_locs)
        for u_id in get_neighbors(G, v_id)
            u = get(G, u_id)
            filter!(w_id -> w_id != v_id, u.neigh)
        end
        MAPPFD.get(G, v_id).neigh = []
    end

    return G
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

function check_valid_transition(G::Graph, C_from::Config, C_to::Config)
    N = length(C_from)
    for i = 1:N
        v_i_from = C_from[i]
        v_i_to = C_to[i]
        # move
        @assert(
            v_i_to == v_i_from || v_i_to in get_neighbors(G, v_i_from),
            "invalid move for agent-$i: from $(v_i_from) -> $(v_i_to)"
        )
        for j = i+1:N
            v_j_from = C_from[j]
            v_j_to = C_to[j]
            # check collisions
            @assert(
                v_j_from != v_i_from,
                "vertex collision between agent-$i and agent-$j at vertex-$(v_i_from)"
            )
            @assert(
                v_j_from != v_i_to || v_j_to != v_i_from,
                "edge collision between agent-$i and agent-$j at vertex [$v_i_from, $v_i_to]"
            )
        end
    end
end

function get_path_length(path::Path)::Int
    cost = 0
    v_pre = first(path)
    for v in path
        v_pre == v && continue
        cost += 1
        v_pre = v
    end
    return cost
end

function get_traveling_time(path::Path)::Int
    i = length(path) - 1
    while i >= 1 && path[i] == last(path)
        i -= 1
    end
    return i
end
