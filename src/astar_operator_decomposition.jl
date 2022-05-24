@kwdef struct AODNode <: SearchNode
    Q::Config
    Q_prev::Config
    next::Int
    parent::Union{Nothing,AODNode} = nothing
    g::Real = 0  # g-value
    h::Real = 0  # h-value
    f::Real = g + h  # f-value
    timestep::Int = 1
end

function astar_operator_decomposition(
    G::Graph,
    starts::Config,
    goals::Config;
    dist_tables::Vector{Vector{Int}} = get_distance_tables(G, goals),
)::Union{Nothing,Paths}

    N = length(starts)
    Q_init = copy(starts)
    h_init = sum(i -> dist_tables[i][Q_init[i]], 1:N)
    initial_node = AODNode(Q = Q_init, Q_prev = Q_init, next = 1, h = h_init)

    invalid =
        (S_from, S_to) -> begin
            i = S_from.next
            v_i_from = S_to.Q[i]
            v_i_to = S_to.Q[i]
            # avoid collision
            return any(
                j ->
                    S_to.Q[j] == v_i_to ||
                        (S_to.Q[j] == v_i_from && S_to.Q_prev[j] == v_i_to),
                1:i-1,
            )
        end

    get_node_neighbors =
        (S) -> begin
            i = S.next
            j = mod1(S.next + 1, N)
            v_from = S.Q[i]
            timestep = (j == 1) ? S.timestep + 1 : S.timestep
            return map(
                v_to -> AODNode(
                    Q = map(k -> k == i ? v_to : S.Q[k], 1:N),
                    Q_prev = (j == 1) ? copy(S.Q) : copy(S.Q_prev),
                    next = j,
                    g = v_to == goals[i] ? S.g : S.g + 1,  # minimize time not at goal
                    h = S.h - dist_tables[i][v_from] + dist_tables[i][v_to],
                    parent = S,
                    timestep = timestep,
                ),
                vcat(get_neighbors(G, v_from), v_from),
            )
        end

    backtrack =
        (S) -> begin
            paths = map(j -> Vector{Int}(), 1:N)
            while !isnothing(S.parent)
                S.next == 1 && foreach(k -> pushfirst!(paths[k], S.Q[k]), 1:N)
                S = S.parent
            end
            foreach(k -> pushfirst!(paths[k], S.Q[k]), 1:N)
            return paths
        end

    return search(
        initial_node = initial_node,
        invalid = invalid,
        check_goal = (S) -> S.Q == goals && S.next == 1,
        get_node_neighbors = get_node_neighbors,
        get_node_id = (S) -> "$(join(S.Q, '-'))_(S.next)",
        get_node_score = (S) -> S.f,
        backtrack = backtrack,
    )
end
