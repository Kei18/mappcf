module SingleAgentPathfinding

export get_distance_table, timed_pathfinding, basic_pathfinding

import Base: @kwdef
import MAPPFD: Graph, get_neighbors, Path, Config, search, SearchNode
import DataStructures: Queue, PriorityQueue, enqueue!, dequeue!

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
)::Union{Nothing,Path}
    return search(
        initial_node = TimedNode(v = start, t = 1, h = h_func(start)),
        invalid = invalid,
        check_goal = check_goal,
        get_node_neighbors = (S) -> map(
            u -> TimedNode(v = u, t = S.t + 1, parent = S, g = S.g + 1, h = h_func(u)),
            vcat(get_neighbors(G, S.v), S.v),
        ),
        get_node_id = (S) -> "$(S.v)-$(S.t)",
        get_node_score = (S) -> S.f,
        backtrack = backtrack_single_agent,
    )
end

function backtrack_single_agent(S::Union{BasicNode,TimedNode})::Path
    path = Path()
    while !isnothing(S.parent)
        pushfirst!(path, S.v)
        S = S.parent
    end
    pushfirst!(path, S.v)
    return path
end

function get_distance_table(G::Graph, goal::Int)::Vector{Int}
    table = fill(typemax(Int), length(G))
    OPEN = Queue{Int}()

    # setup initial vertex
    table[goal] = 0
    enqueue!(OPEN, goal)

    while !isempty(OPEN)
        # pop
        loc = dequeue!(OPEN)
        d = table[loc]

        # expand
        for u_id in get_neighbors(G, loc)
            g = d + 1
            # update distance
            if g < table[u_id]
                table[u_id] = g
                enqueue!(OPEN, u_id)
            end
        end
    end

    return table
end

function is_valid_path(path::Path, G::Graph, start::Int, goal::Int; VERBOSE::Int = 0)::Bool
    if first(path) != start
        VERBOSE > 0 && @warn("invalid start")
        return false
    end
    if last(path) != goal
        VERBOSE > 0 && @warn("invalid goal")
        return false
    end
    if any(
        t -> path[t] != path[t-1] && !(path[t] in get_neighbors(G, path[t-1])),
        2:length(path),
    )
        VERBOSE > 0 && @warn("invalid move")
        return false
    end
    return true
end

end
