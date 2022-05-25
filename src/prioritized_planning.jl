function prioritized_planning(
    G::Graph,
    starts::Config,
    goals::Config;
    dist_tables::Vector{Vector{Int}} = get_distance_tables(G, goals),
)::Union{Nothing,Paths}
    N = length(starts)
    paths = map(i -> Path(), 1:N)

    for i = 1:N

        h_func = (v) -> dist_tables[i][v]

        invalid =
            (S_from, S_to) -> begin
                # TODO: optimize this procedure
                v_i_from = S_from.v
                v_i_to = S_to.v
                t = S_to.t

                # avoid other goals
                v_i_to != goals[i] && v_i_to in goals && return true

                # collision
                for j = 1:N
                    (j == i || isempty(paths[j])) && continue
                    v_j_from = get_in_range(paths[j], t - 1)
                    v_j_to = get_in_range(paths[j], t)
                    # vertex or edge collision
                    (v_i_to == v_j_to) && return true
                    (v_j_to == v_i_from && v_j_from == v_i_to) && return true
                end
                return false
            end

        path = timed_pathfinding(
            G = G,
            start = starts[i],
            check_goal = gen_check_goal_pp(paths, i, goals[i]),
            invalid = invalid,
            h_func = h_func,
        )

        # failure case
        isnothing(path) && return nothing

        # register
        paths[i] = path
    end

    return paths
end

function gen_check_goal_pp(paths::Paths, i::Int, goal::Int)::Function
    # compute last timestep when the goal is used by other agents
    last_timestep_goal_used = 0
    for (j, path) in enumerate(paths)
        j == i && continue
        for t = max(1, last_timestep_goal_used):length(path)
            if path[t] == goal
                last_timestep_goal_used = max(last_timestep_goal_used, t)
            end
        end
    end

    return (S) -> begin
        S.v != goal && return false
        S.t <= last_timestep_goal_used && return false
        return true
    end
end
