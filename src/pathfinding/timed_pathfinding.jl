@kwdef struct TimedNode <: SearchNode
    v::Int64  # where
    t::Int64  # when
    parent::Union{Nothing,TimedNode} = nothing  # parent
    g::Real = 0  # g-value
    h::Real = 0  # h-value
    f::Real = g + h  # f-value
end

function timed_pathfinding(;
    G::Graph,
    start::Int,
    check_goal::Function,
    invalid::Function = (S_from, S_to) -> false,
    h_func::Function = (u) -> 0,
    timestep_limit::Union{Nothing,Int} = nothing,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    kwargs...,
)::Union{Nothing,Path}

    invalid_with_timestep_limit =
        (S_from::TimedNode, S_to::TimedNode) -> begin
            invalid(S_from, S_to) && return true
            !isnothing(timestep_limit) && S_to.t > timestep_limit && return true
            return false
        end

    return search(;
        initial_node = TimedNode(v = start, t = 1, h = h_func(start)),
        invalid = invalid_with_timestep_limit,
        check_goal = check_goal,
        get_node_neighbors = (S) -> map(
            u -> TimedNode(v = u, t = S.t + 1, parent = S, g = S.g + 1, h = h_func(u)),
            vcat(get_neighbors(G, S.v), S.v),
        ),
        get_node_id = (S) -> "$(S.v)-$(S.t)",
        get_node_score = (S) -> S.f,
        backtrack = backtrack_single_agent,
        deadline = deadline,
    )
end
