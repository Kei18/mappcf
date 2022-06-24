@kwdef struct BasicNode <: SearchNode
    v::Int  # where
    parent::Union{Nothing,BasicNode} = nothing
    g::Int = 0
    h::Int = 0
    f::Int = g + h
end
Base.lt(o::FastForwardOrdering, a::BasicNode, b::BasicNode) = a.f < b.f
Base.string(S::BasicNode) = string(S.v)

function basic_pathfinding(;
    G::Graph,
    start::Int,
    goal::Int,
    invalid::Function = (S_from::BasicNode, S_to::BasicNode) -> false,
    h_func = (u::Int) -> 0,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    kwargs...,
)::Union{Nothing,Path}

    return search(;
        initial_node = BasicNode(v = start, h = h_func(start)),
        invalid = invalid,
        check_goal = (S::BasicNode) -> S.v == goal,
        get_node_neighbors = (S::BasicNode) -> map(
            u -> BasicNode(v = u, parent = S, g = S.g + 1, h = h_func(u)),
            get_neighbors(G, S.v),
        ),
        get_node_id = (S::BasicNode) -> S.v,
        backtrack = backtrack_single_agent,
        NameDataType = Int,
        deadline = deadline,
        kwargs...,
    )
end
