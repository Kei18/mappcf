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
Base.lt(o::FastForwardOrdering, a::AODNode, b::AODNode) = a.f < b.f

# pure implementation
function astar_operator_decomposition(
    G::Graph,
    starts::Config,
    goals::Config;
    h_func = gen_h_func(G, goals),
    timestep_limit::Union{Nothing,Int} = nothing,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    kwargs...,
)::Union{Nothing,Paths}

    return search(;
        initial_node = get_initial_AODNode(starts, h_func),
        invalid = gen_invalid_AOD(goals; timestep_limit = timestep_limit),
        check_goal = (S) -> S.Q == goals && S.next == 1,
        get_node_neighbors = gen_get_node_neighbors_AOD(G, goals, h_func),
        get_node_id = (S) -> string(S),
        backtrack = backtrack_AOD,
        deadline = deadline,
        kwargs...,
    )
end

function get_initial_AODNode(starts::Config, h_func::Function)::AODNode
    Q_init = copy(starts)
    h_init = sum(i -> h_func(i)(Q_init[i]), 1:length(starts))
    return AODNode(Q = Q_init, Q_prev = Q_init, next = 1, h = h_init)
end

function gen_invalid_AOD(
    goals::Config;
    timestep_limit::Union{Nothing,Real} = nothing,
    correct_agents::Vector{Int} = collect(1:length(goals)),
    additional_constraints::Union{Nothing,Function} = nothing,
)::Function

    correct_agents_goals = map(i -> goals[i], correct_agents)

    return (S_from::AODNode, S_to::AODNode) -> begin
        !isnothing(timestep_limit) && S_to.timestep > timestep_limit && return true

        i = S_from.next
        v_i_from = S_from.Q[i]
        v_i_to = S_to.Q[i]

        # check collision
        any(
            j ->
                S_to.Q[j] == v_i_to ||
                    (S_to.Q[j] == v_i_from && S_to.Q_prev[j] == v_i_to),
            1:i-1,
        ) && return true

        # avoid others goals
        v_i_to != goals[i] && v_i_to in correct_agents_goals && return true

        # check additional constrains
        !isnothing(additional_constraints) &&
            additional_constraints(S_from, S_to) &&
            return true

        return false
    end
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
    h_func::Function,
    fixed_agents::Vector{Int} = Vector{Int}(),
)::Function

    N = length(goals)

    return (S::AODNode) -> begin
        i = S.next
        j = mod1(S.next + 1, N)
        v_from = S.Q[i]
        timestep = (j == 1) ? S.timestep + 1 : S.timestep
        return map(
            v_to -> begin
                AODNode(
                    Q = map(k -> k == i ? v_to : S.Q[k], 1:N),
                    Q_prev = (i == 1) ? copy(S.Q) : copy(S.Q_prev),
                    next = j,
                    g = (v_to == goals[i]) ? S.g : S.g + 1,  # minimize time not at goal
                    h = S.h - h_func(i)(v_from) + h_func(i)(v_to),
                    parent = S,
                    timestep = timestep,
                )
            end,
            i in fixed_agents ? [v_from] : vcat(get_neighbors(G, v_from), v_from),
        )
    end
end

Base.string(S::AODNode) = "$(join(S.Q, '-'))_$(S.next)"
