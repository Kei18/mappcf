function get_distance_table(G::Graph, goal::Int)::Vector{Int}
    table = fill(typemax(Int), length(G))
    OPEN = PriorityQueue{Int,Int}()

    # setup initial vertex
    table[goal] = 0
    enqueue!(OPEN, goal, 0)

    while !isempty(OPEN)
        # pop
        loc = dequeue!(OPEN)
        d = table[loc]

        # expand
        for u_id in get_neighbors(G, loc)
            g = d + 1
            # update distance
            if g < table[u_id]
                haskey(OPEN, u_id) && delete!(OPEN, u_id)
                table[u_id] = g
                enqueue!(OPEN, u_id, g)
            end
        end
    end

    return table
end

@kwdef struct SearchNode
    v::Int64  # where
    t::Int64  # when
    id::String = @sprintf("%d-%d", v, t)  # id of search node
    parent_id::Union{Nothing,String} = nothing  # parent in the search tree
    g::Real = 0  # g-value
    h::Real = 0  # h-value
    f::Real = g + h  # f-value
    unique_id::Int64 = 1   # to avoid duplication
end

function find_timed_path(
    G::Graph,
    start::Int,
    check_goal::Function;
    invalid::Function = (args...) -> false,
    h_func::Function = (args...) -> 0,
    g_func::Function = (S::SearchNode, u::Int) -> S.g + 1,
)::Union{Nothing,Path}  # failure or path

    CLOSE = Dict{String,SearchNode}()
    OPEN = PriorityQueue{SearchNode,Real}()

    # for uniqueness
    num_generated_nodes = 1

    # setup initial node
    S_init =
        SearchNode(v = start, t = 1, h = h_func(start), unique_id = num_generated_nodes)

    # insert initial node
    enqueue!(OPEN, S_init, S_init.f)

    # main loop
    while !isempty(OPEN)

        # pop
        S = dequeue!(OPEN)
        haskey(CLOSE, S.id) && continue
        CLOSE[S.id] = S

        # check goal condition
        if check_goal(S)
            # backtracking
            path = []
            while !isnothing(S.parent_id)
                pushfirst!(path, S.v)
                S = CLOSE[S.parent_id]
            end
            pushfirst!(path, start)
            return path
        end

        # expand
        for u in get_neighbors(G, S.v)
            num_generated_nodes += 1
            S_new = SearchNode(
                v = u,
                t = S.t + 1,
                parent_id = S.id,
                g = g_func(S, u),
                h = h_func(u),
                unique_id = num_generated_nodes,
            )
            (haskey(CLOSE, S_new.id) || invalid(S, S_new)) && continue
            enqueue!(OPEN, S_new, S_new.f)
        end
    end

    return nothing
end

function align_paths!(paths::Paths)::Nothing
    max_len = maximum(map(length, paths))
    N = length(paths)

    # align length
    for i = 1:N
        while length(paths[i]) < max_len
            push!(paths[i], paths[i][end])
        end
    end

    # remove redundant timesteps
    while length(paths[1]) > 1 && all(path -> path[end] == path[end-1], paths)
        foreach(pop!, paths)
    end
end

function single_agent_pathfinding(
    G::Graph,
    paths::Paths,
    agent::Int,
    start::Int,
    goal::Int;
    max_makespan::Union{Int,Nothing} = 10,
    h_func = (v::Int) -> 0,
)::Path
    N = length(paths)

    # check collisions
    invalid =
        (S_from::SearchNode, S_to::SearchNode) -> begin
            v_i_from = S_from.v
            v_i_to = S_to.v
            t = S_to.t
            !isnothing(max_makespan) && t > max_makespan && return true
            for j = 1:N
                (j == agent || isempty(paths[j])) && continue
                l = length(paths[j])
                v_j_from = paths[j][min(t - 1, l)]
                v_j_to = paths[j][min(t, l)]
                # vertex or edge collision
                (v_i_to == v_j_to || (v_j_from == v_i_from && v_j_to == v_i_from)) &&
                    return true
            end
            return false
        end

    # check goal
    check_goal =
        (S::SearchNode) -> begin
            S.v != goal && return false
            # check additional constraints
            for j = 1:N
                j == agent && continue
                any(t -> paths[j][t] == S.v, S.t+1:length(paths[j])) && return false
            end
            return true
        end

    # single-agent path finding
    return find_timed_path(G, start, check_goal; invalid = invalid, h_func = h_func)
end

function prioritized_planning(
    G::Graph,
    starts::Config,
    goals::Config;
    max_makespan::Union{Nothing,Int} = 20,
    align_length::Bool = true,
    dist_tables::Vector{Vector{Int}} = map(g -> get_distance_table(G, g), goals),
)::Union{Nothing,Paths}
    N = length(starts)
    paths = map(i -> Path(), 1:N)

    for i = 1:N
        # single-agent path finding
        path = single_agent_pathfinding(
            G,
            paths,
            i,
            starts[i],
            goals[i];
            max_makespan = max_makespan,
            h_func = (v_id) -> dist_tables[i][v_id],
        )

        # failure case
        isnothing(path) && return nothing

        paths[i] = path
    end

    # align length
    align_length && align_paths!(paths)

    return paths
end
