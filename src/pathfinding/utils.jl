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

function backtrack_single_agent(S::SearchNode)::Path
    path = Path()
    while !isnothing(S.parent)
        pushfirst!(path, S.v)
        S = S.parent
    end
    pushfirst!(path, S.v)
    return path
end
