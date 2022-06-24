@kwdef struct BasicNode <: SearchNode
    v::Int  # where
    parent::Union{Nothing,BasicNode} = nothing
    g::Int = 0
    h::Int = 0
    f::Int = g + h
    uuid::Int
end
Base.lt(o::FastForwardOrdering, a::BasicNode, b::BasicNode) = a.f < b.f

function basic_pathfinding(;
    G::Graph,
    start::Int,
    goal::Int,
    invalid::Function = (S_from, S_to) -> false,
    h_func = (u) -> 0,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    kwargs...,
)::Union{Nothing,Path}

    uuid = 1
    return search(;
        initial_node = BasicNode(v = start, h = h_func(start), uuid = uuid),
        invalid = invalid,
        check_goal = (S) -> S.v == goal,
        get_node_neighbors = (S) -> map(
            u -> begin
                uuid += 1
                BasicNode(v = u, parent = S, g = S.g + 1, h = h_func(u), uuid = uuid)
            end,
            get_neighbors(G, S.v),
        ),
        get_node_id = (S) -> S.v,
        backtrack = backtrack_single_agent,
        deadline = deadline,
        kwargs...,
    )
end
