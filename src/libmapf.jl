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
