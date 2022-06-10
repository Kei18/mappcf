function get_distance_table(
    G::Graph,
    goal::Int,
    prohibited_locs::Vector{Int} = Vector{Int}(),
)::Vector{Int}
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
            u_id in prohibited_locs && continue
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

function gen_h_func(G::Graph, goals::Config)::Function
    dist_tables = get_distance_tables(G, goals)
    return (i) -> begin
        (v) -> dist_tables[i][v]
    end
end

function gen_h_func(ins::SyncInstance)::Function
    return gen_h_func(ins.G, ins.goals)
end

function gen_h_func(ins::SeqInstance)::Function
    return gen_h_func(ins.G, ins.goals)
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
