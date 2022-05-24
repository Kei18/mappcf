module PathFinding

import Base: @kwdef
import MAPPFD: Graph, get_neighbors, Path, Config
import DataStructures: Queue, PriorityQueue, enqueue!, dequeue!

abstract type SearchNode end

function astar_search(;
    G::Graph,
    start::Int,
    check_goal::Function,
    invalid::Function,
    neighbors::Function,
    create_new_node::Function,
)::Union{Nothing,Path}  # failure or path

    OPEN = PriorityQueue{SearchNode,Real}()
    CLOSED = Dict{String,Bool}()

    # setup initial node
    S = create_new_node(start)

    # insert initial node
    enqueue!(OPEN, S, S.f)

    # main loop
    while !isempty(OPEN)

        # pop
        S = dequeue!(OPEN)
        S_id = string(S)
        haskey(CLOSED, S_id) && continue
        CLOSED[S_id] = true

        # check goal condition
        check_goal(S) && return backtrack(S)

        # expand
        for u in neighbors(S)
            S_new = create_new_node(u, S)
            S_new_id = string(S_new)
            (haskey(CLOSED, S_new_id) || invalid(S, S_new)) && continue
            !haskey(OPEN, S_new) && enqueue!(OPEN, S_new, S_new.f)
        end
    end
    return nothing
end

function backtrack(S::T where {T<:SearchNode})::Path
    path = Path()
    while !isnothing(S.parent)
        pushfirst!(path, S.v)
        S = S.parent
    end
    pushfirst!(path, S.v)
    return path
end

@kwdef struct TimedNode <: SearchNode
    v::Int64  # where
    t::Int64  # when
    parent::Union{Nothing,TimedNode} = nothing  # parent
    g::Real = 0  # g-value
    h::Real = 0  # h-value
    f::Real = g + h  # f-value
end
Base.string(S::TimedNode) = "$(S.v)-$(S.t)"

function timed_path_finding(;
    G::Graph,
    start::Int,
    check_goal::Function,
    invalid::Function = (S_from, S_to) -> false,
    h_func::Function = (u) -> 0,
)::Union{Nothing,Path}
    return astar_search(
        G = G,
        start = start,
        check_goal = check_goal,
        invalid = invalid,
        neighbors = (S) -> vcat(get_neighbors(G, S.v), S.v),
        create_new_node = (u, S = nothing) -> TimedNode(
            v = u,
            t = isnothing(S) ? 1 : S.t + 1,
            parent = S,
            g = isnothing(S) ? 1 : S.g + 1,
            h = h_func(u),
        ),
    )
end

@kwdef struct BasicNode <: SearchNode
    v::Int  # where
    parent::Union{Nothing,BasicNode} = nothing
    g::Int = 0
    h::Int = 0
    f::Int = g + h
end
Base.string(S::BasicNode) = "$(S.v)"

function basic_path_finding(;
    G::Graph,
    start::Int,
    goal::Int,
    invalid::Function = (S_from, S_to) -> false,
    h_func = (u) -> 0,
)
    return astar_search(
        G = G,
        start = start,
        check_goal = (S) -> S.v == goal,
        invalid = invalid,
        neighbors = (S) -> get_neighbors(G, S.v),
        create_new_node = (u, S = nothing) ->
            BasicNode(v = u, parent = S, g = isnothing(S) ? 1 : S.g + 1, h = h_func(u)),
    )
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

function get_distance_tables(G::Graph, goals::Config)::Vector{Vector{Int}}
    return map(g -> get_distance_table(G, g), goals)
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
