@kwdef mutable struct Vertex
    id::Int  # unique id
    pos::Vector{Real} = rand(2)  # assuming 2d
    neigh::Vector{Int} = [] # indexes
end
Graph = Vector{Vertex}

function get(G::Graph, loc::Int)
    return G[loc]
end

function get_neighbors(G::Graph, loc::Int)::Vector{Int}
    return G[loc].neigh
end

function generate_sample_graph1()::Graph
    # setup undirected graph
    G = map(i -> Vertex(id=i), 1:5)

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
