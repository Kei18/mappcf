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
        for u in vcat(get_neighbors(G, S.v), S.v)
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

function remove_redundant_vertices!(paths::Paths)::Nothing
    N = length(paths)
    for i = 1:N
        while length(paths[i]) > 1 && paths[i][end-1] == paths[i][end]
            pop!(paths[i])
        end
    end
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
    goals::Config;
    max_makespan::Union{Int,Nothing} = 10,
    h_func = (v::Int) -> 0,
    correct_agents::Vector{Int} = collect(1:length(paths)),
)::Union{Nothing,Path}
    N = length(paths)
    goal = goals[agent]

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
                (v_i_to == v_j_to || (v_j_to == v_i_from && v_j_from == v_i_to)) &&
                    return true
            end

            # avoid goals of others
            any(j -> j != agent && goals[j] == S_to.v, correct_agents) && return true

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
    dist_tables::Vector{Vector{Int}} = get_distance_tables(G, goals),
    avoid_duplicates::Bool = true,
)::Union{Nothing,Paths}
    N = length(starts)
    paths = map(i -> Path(), 1:N)

    for i = 1:N
        h_func =
            !avoid_duplicates ? (v_id) -> dist_tables[i][v_id] :
            (v_id) -> begin
                c = sum(map(j -> begin
                            j > i && starts[j] == v_id && return 1
                            j < i && return count(j -> starts[j] == v_id, i+1:N)
                            return 0
                        end, 1:N))
                return dist_tables[i][v_id] + c / 1000
            end

        # single-agent path finding
        path = single_agent_pathfinding(
            G,
            paths,
            i,
            starts[i],
            goals;
            max_makespan = max_makespan,
            h_func = h_func,
        )

        # failure case
        isnothing(path) && return nothing

        paths[i] = path
    end

    # align length
    align_length && align_paths!(paths)

    return paths
end

@kwdef mutable struct AODNode
    Q::Config
    Q_prev::Config
    next::Int
    id::String = get_Q_id(Q, next)
    parent_id::Union{Nothing,String} = nothing  # parent node
    g::Float64 = 0.0  # g-value
    h::Float64 = 0.0  # h-value
    f::Float64 = g + h  # f-value
    timestep::Int = 1
end


function astar_operator_decomposition(
    G::Graph,
    starts::Config,
    goals::Config;
    dist_tables::Vector{Vector{Int}} = map(g -> get_distance_table(G, g), goals),
)::Union{Nothing,Paths}

    # greedy search

    N = length(starts)
    OPEN = PriorityQueue{AODNode,Float64}()
    VISITED = Dict{String,AODNode}()

    # setup initial node
    Q_init = copy(starts)
    h_init = sum(i -> dist_tables[i][Q_init[i]], 1:N)
    S_init = AODNode(Q = Q_init, Q_prev = Q_init, next = 1, h = h_init)
    enqueue!(OPEN, S_init, S_init.f)
    VISITED[S_init.id] = S_init

    loop_cnt = 0
    while !isempty(OPEN)
        loop_cnt += 1

        # pop
        S = dequeue!(OPEN)

        # check goal, backtracking
        if S.Q == goals && S.next == 1
            paths = map(j -> Vector{Int}(), 1:N)
            while !isnothing(S.parent_id)
                S.next == 1 && foreach(k -> pushfirst!(paths[k], S.Q[k]), 1:N)
                S = VISITED[S.parent_id]
            end
            foreach(k -> pushfirst!(paths[k], S.Q[k]), 1:N)
            return paths
        end

        # expand
        i = S.next
        j = mod1(S.next + 1, N)
        u = S.Q[i]
        for v in vcat(get_neighbors(G, u), u)
            Q_new = copy(S.Q)
            Q_new[i] = v
            # check collision
            any(j -> Q_new[j] == v || (Q_new[j] == u && S.Q_prev[j] == v), 1:i-1) &&
                continue

            h = S.h - dist_tables[i][u] + dist_tables[i][v]
            S_new = AODNode(
                Q = Q_new,
                Q_prev = (j == 1) ? copy(S.Q) : copy(S.Q_prev),
                next = j,
                h = h,
                parent_id = S.id,
            )
            # avoid duplication
            haskey(VISITED, S_new.id) && continue
            # insert
            enqueue!(OPEN, S_new, S_new.f)
            VISITED[S_new.id] = S_new
        end
    end
end

function astar_operator_decomposition(
    G::Graph,
    starts::Config,
    goals::Config,
    crashes,
    constraints,
    time_offset::Int,
    ;
    dist_tables::Vector{Vector{Int}} = map(g -> get_distance_table(G, g), goals),
)::Union{Nothing,Paths}

    N = length(starts)
    crashed_agents::Vector{Int} = map(c -> c.who, crashes)
    correct_agents = filter(i -> !(i in crashed_agents), 1:N)

    OPEN = PriorityQueue{AODNode,Float64}()
    VISITED = Dict{String,AODNode}()

    # setup initial node
    Q_init = copy(starts)
    h_init = sum(i -> dist_tables[i][Q_init[i]], 1:N)
    S_init = AODNode(Q = Q_init, Q_prev = Q_init, next = 1, h = h_init)
    enqueue!(OPEN, S_init, S_init.f)
    VISITED[S_init.id] = S_init

    loop_cnt = 0
    while !isempty(OPEN)
        loop_cnt += 1

        # pop
        S = dequeue!(OPEN)

        # check goal, backtracking
        if all(k -> S.Q[k] == goals[k], correct_agents) && S.next == 1
            paths = map(j -> Vector{Int}(), 1:N)
            while !isnothing(S.parent_id)
                S.next == 1 && foreach(k -> pushfirst!(paths[k], S.Q[k]), 1:N)
                S = VISITED[S.parent_id]
            end
            foreach(k -> pushfirst!(paths[k], S.Q[k]), 1:N)
            remove_redundant_vertices!(paths)
            return paths
        end

        # expand
        i = S.next
        j = mod1(S.next + 1, N)
        u = S.Q[i]
        for v in ((i in crashed_agents) ? [u] : vcat(get_neighbors(G, u), u))
            Q_new = copy(S.Q)
            Q_new[i] = v
            # check collision
            any(j -> Q_new[j] == v || (Q_new[j] == u && S.Q_prev[j] == v), 1:i-1) &&
                continue
            # check constraints
            i in correct_agents &&
                any(
                    c ->
                        c.loc == v &&
                            c.who == i &&
                            c.when - time_offset + 1 <= S.timestep + 1,
                    constraints,
                ) &&
                continue

            h = S.h - dist_tables[i][u] + dist_tables[i][v]
            S_new = AODNode(
                Q = Q_new,
                Q_prev = (j == 1) ? copy(S.Q) : copy(S.Q_prev),
                next = j,
                h = h,
                parent_id = S.id,
                timestep = (j == 1) ? S.timestep + 1 : S.timestep,
            )
            # avoid duplication
            haskey(VISITED, S_new.id) && continue
            # insert
            enqueue!(OPEN, S_new, S_new.f)
            VISITED[S_new.id] = S_new
        end
    end
end


function get_Q_id(Q::Config, next::Int)::String
    return @sprintf("%s_%d", join(Q, "-"), next)
end


function verify_mapf_solution(
    G::Graph,
    starts::Config,
    goals::Config,
    solution::Union{Nothing,Paths};
    VERBOSE::Int = 0,
)

    N = length(starts)

    # starts
    if any(i -> first(solution[i]) != starts[i], 1:N)
        VERBOSE > 0 && @warn("inconsistent starts")
        return false
    end
    # goals
    if any(i -> last(solution[i]) != goals[i], 1:N)
        VERBOSE > 0 && @warn("inconsistent goals")
        return false
    end

    # check for each timestep
    T = maximum(i -> length(solution[i]), 1:N)
    for t = 1:T
        for i = 1:N
            v_i_now = solution[i][t]
            v_i_pre = solution[i][max(1, t - 1)]
            # check continuity
            if !(v_i_now in vcat(get_neighbors(G, v_i_pre), v_i_pre))
                VERBOSE > 0 && @warn("$agent-(i)'s path is invalid at timestep $(t)")
                return false
            end
            # check collisions
            for j = i+1:N
                v_j_now = solution[j][t]
                v_j_pre = solution[j][max(1, t - 1)]
                if v_i_now == v_j_now || (v_i_now == v_j_pre && v_i_pre == v_j_now)
                    VERBOSE > 0 &&
                        @warn("collisions between $(i) and $(j) at timestep $(t)")
                    return false
                end
            end
        end
    end

    return true
end
