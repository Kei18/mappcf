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

# pure implementation
function astar_operator_decomposition(
    G::Graph,
    starts::Config,
    goals::Config;
    dist_tables::Vector{Vector{Int}} = get_distance_tables(G, goals),
)::Union{Nothing,Paths}

    invalid = (S_from, S_to) -> begin
        # avoid collisions
        invalid_AOD(S_from, S_to) && return true
        # avoid other goals
        i = S_from.next
        v = S_to.Q[i]
        v != goals[i] && v in goals && return true

        return false
    end

    return search(
        initial_node = get_initial_AODNode(starts, dist_tables),
        invalid = invalid,
        check_goal = (S) -> S.Q == goals && S.next == 1,
        get_node_neighbors = gen_get_node_neighbors_AOD(G, goals, dist_tables),
        get_node_id = (S) -> string(S),
        get_node_score = (S) -> S.f,
        backtrack = backtrack_AOD,
    )
end

function get_initial_AODNode(starts::Config, dist_tables::Vector{Vector{Int}})::AODNode
    Q_init = copy(starts)
    h_init = sum(i -> dist_tables[i][Q_init[i]], 1:length(starts))
    return AODNode(Q = Q_init, Q_prev = Q_init, next = 1, h = h_init)
end

function invalid_AOD(S_from::AODNode, S_to::AODNode)::Bool
    i = S_from.next
    v_i_from = S_to.Q[i]
    v_i_to = S_to.Q[i]
    # avoid collision
    return any(
        j -> S_to.Q[j] == v_i_to || (S_to.Q[j] == v_i_from && S_to.Q_prev[j] == v_i_to),
        1:i-1,
    )
end

function backtrack_AOD(S::AODNode)::Paths
    N = length(S.Q)
    paths = map(j -> Path(), 1:N)
    while !isnothing(S.parent)
        S.next == 1 && foreach(k -> pushfirst!(paths[k], S.Q[k]), 1:N)
        S = S.parent
    end
    foreach(k -> pushfirst!(paths[k], S.Q[k]), 1:N)
    # remove redundant vertex
    for i = 1:N
        while length(paths[i]) > 1 && paths[i][end] == paths[i][end-1]
            pop!(paths[i])
        end
    end
    return paths
end

function gen_get_node_neighbors_AOD(
    G::Graph,
    goals::Config,
    dist_tables::Vector{Vector{Int}},
    fixed_agents::Vector{Int} = Vector{Int}(),
)::Function

    N = length(goals)

    return (S::AODNode) -> begin
        i = S.next
        j = mod1(S.next + 1, N)
        v_from = S.Q[i]
        timestep = (j == 1) ? S.timestep + 1 : S.timestep
        return map(
            v_to -> AODNode(
                Q = map(k -> k == i ? v_to : S.Q[k], 1:N),
                Q_prev = (j == 1) ? copy(S.Q) : copy(S.Q_prev),
                next = j,
                g = (v_to == goals[i]) ? S.g : S.g + 1,  # minimize time not at goal
                h = S.h - dist_tables[i][v_from] + dist_tables[i][v_to],
                parent = S,
                timestep = timestep,
            ),
            i in fixed_agents ? [v_from] : vcat(get_neighbors(G, v_from), v_from),
        )
    end
end

Base.string(S::AODNode) = "$(join(S.Q, '-'))_$(S.next)"
