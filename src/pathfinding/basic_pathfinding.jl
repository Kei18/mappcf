@kwdef struct BasicNode <: SearchNode
    v::Int  # where
    parent::Union{Nothing,BasicNode} = nothing
    g::Int = 0
    h::Int = 0
    f::Int = g + h
end

function basic_pathfinding(;
    G::Graph,
    start::Int,
    goal::Int,
    invalid::Function = (S_from, S_to) -> false,
    h_func = (u) -> 0,
)::Union{Nothing,Path}
    return search(
        initial_node = BasicNode(v = start, h = h_func(start)),
        invalid = invalid,
        check_goal = (S) -> S.v == goal,
        get_node_neighbors = (S) -> map(
            u -> BasicNode(v = u, parent = S, g = S.g + 1, h = h_func(u)),
            get_neighbors(G, S.v),
        ),
        get_node_id = (S) -> S.v,
        get_node_score = (S) -> S.f,
        backtrack = backtrack_single_agent,
    )
end
