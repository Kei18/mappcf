@kwdef struct TimedNode <: SearchNode
    v::Int64  # where
    t::Int64  # when
    parent::Union{Nothing,TimedNode} = nothing  # parent
    g::Real = 0  # g-value
    h::Real = 0  # h-value
    f::Real = g + h * 1.00001 # f-value
    uuid::Int
end
Base.lt(o::FastForwardOrdering, a::TimedNode, b::TimedNode) = a.f < b.f

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
    uuid = 1

    return search(;
        initial_node = TimedNode(v = start, t = 1, h = h_func(start), uuid = uuid),
        invalid = invalid_with_timestep_limit,
        check_goal = check_goal,
        get_node_neighbors = (S) -> map(
            u -> begin
                uuid += 1
                TimedNode(
                    v = u,
                    t = S.t + 1,
                    parent = S,
                    g = S.g + 1,
                    h = h_func(u),
                    uuid = uuid,
                )
            end,
            vcat(get_neighbors(G, S.v), S.v),
        ),
        get_node_id = (S) -> "$(S.v)-$(S.t)",
        backtrack = backtrack_single_agent,
        deadline = deadline,
    )
end
