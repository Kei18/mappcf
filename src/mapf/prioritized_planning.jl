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
    avoid_duplicates::Bool = false,
    planning_order = collect(1:length(starts)),
    VERBOSE::Int = 0,
    kwargs...,
)::Union{Nothing,Paths}
    N = length(starts)
    K = length(G)

    paths = map(i -> Path(), 1:N)
    collision_table = []
    used_cnt_table = fill(0, K)

    for i in planning_order
        VERBOSE > 1 && println(
            "elapsed: $(round(elapsed_sec(deadline), digits=3)) s\tagent-$(i) starts planning",
        )
        invalid =
            (S_from, S_to) -> begin
                v_i_from = S_from.v
                v_i_to = S_to.v
                t = S_to.t

                # avoid other starts & goals
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


        h_func_i = h_func(i)
        h_func_i_tiebreak = (v) -> h_func_i(v) + used_cnt_table[v] / 100

        path = timed_pathfinding(
            G = G,
            start = starts[i],
            check_goal = gen_check_goal_pp(paths, i, goals[i]),
            invalid = invalid,
            h_func = avoid_duplicates ? h_func_i_tiebreak : h_func_i,
            deadline = deadline,
            timestep_limit = timestep_limit,
        )

        # failure case
        if isnothing(path)
            VERBOSE > 0 && println(
                "elapsed: $(round(elapsed_sec(deadline), digits=3)) s\tagent-$(i) fails to find a path",
            )
            return nothing
        end

        # register
        paths[i] = path

        # update collision table
        for (t, v) in enumerate(path)
            if length(collision_table) < t
                push!(collision_table, fill(NONE, K))
                for j = 1:N
                    j == i && continue
                    isempty(paths[j]) && continue
                    collision_table[t][paths[j][end]] = j
                end
            end
            collision_table[t][v] = i
            used_cnt_table[v] += 1
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

function PP_repeat(
    args...;
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    VERBOSE::Int = 0,
    kwargs...,
)::Union{Nothing,Paths}
    N = length(args[2])
    iter_cnt = 0
    while !is_expired(deadline)
        iter_cnt += 1
        VERBOSE > 0 && println(
            "elapsed: $(round(elapsed_sec(deadline), digits=3)) s\titer:$(iter_cnt)",
        )
        paths = prioritized_planning(
            args...;
            planning_order = randperm(N),
            deadline = deadline,
            VERBOSE = VERBOSE - 1,
            kwargs...,
        )
        !isnothing(paths) && return paths
    end
    return nothing
end

function RPP(args...; kwargs...)::Union{Nothing,Paths}
    return prioritized_planning(args...; avoid_starts = true, avoid_goals = true, kwargs...)
end

function RPP_repeat(args...; kwargs...)::Union{Nothing,Paths}
    return PP_repeat(args...; avoid_starts = true, avoid_goals = true, kwargs...)
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
