const NONE = 0

function prioritized_planning(
    G::Graph,
    starts::Config,
    goals::Config;
    h_func::Function = gen_h_func(G, goals),
    timestep_limit::Union{Nothing,Real} = nothing,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    avoid_starts::Bool = false,
    avoid_goals::Bool = false,
    VERBOSE::Int = 0,
    kwargs...,
)::Union{Nothing,Paths}
    N = length(starts)
    paths = map(i -> Path(), 1:N)

    K = length(G)
    collision_table = []

    for i = 1:N
        VERBOSE > 1 && println(
            "elapsed:$(round(elapsed_sec(deadline), digits=3))sec\tagent-$(i) starts planning",
        )
        invalid =
            (S_from, S_to) -> begin
                v_i_from = S_from.v
                v_i_to = S_to.v
                t = S_to.t

                # avoid other goals
                avoid_starts && v_i_to != starts[i] && v_i_to in starts && return true
                avoid_goals && v_i_to != goals[i] && v_i_to in goals && return true

                # check collision
                if t <= length(collision_table)
                    # vertex
                    collision_table[t][v_i_to] != NONE && return true
                    # edge
                    collision_table[t][v_i_from] == collision_table[t-1][v_i_to] != NONE && return true
                elseif !isempty(collision_table)
                    collision_table[end][v_i_to] != NONE && return true
                end
                return false
            end

        path = timed_pathfinding(
            G = G,
            start = starts[i],
            check_goal = gen_check_goal_pp(paths, i, goals[i]),
            invalid = invalid,
            h_func = h_func(i),
            deadline = deadline,
            timestep_limit = timestep_limit,
        )

        # failure case
        if isnothing(path)
            VERBOSE > 0 && println(
                "elapsed:$(round(elapsed_sec(deadline), digits=3))s\tagent-$(i) fails to find a path",
            )
            return nothing
        end

        # register
        paths[i] = path

        # update collision table
        for (t, v) in enumerate(path)
            if length(collision_table) < t
                push!(collision_table, fill(NONE, K))
                foreach(j -> collision_table[t][paths[j][end]] = j, 1:i-1)
            end
            collision_table[t][v] = i
        end
        for t = length(path):length(collision_table)
            collision_table[t][path[end]] = i
        end
    end

    return paths
end

function PP(args...; kwargs...)::Union{Nothing,Paths}
    return prioritized_planning(args...; kwargs...)
end

function RPP(args...; kwargs...)::Union{Nothing,Paths}
    return prioritized_planning(args...; avoid_starts = true, avoid_goals = true, kwargs...)
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
