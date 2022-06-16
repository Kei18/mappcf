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
    avoid_duplicates_weight::Real = 0.01,
    planning_order = collect(1:length(starts)),
    VERBOSE::Int = 0,
    kwargs...,
)::Union{Nothing,Paths}
    N = length(starts)
    K = length(G)

    paths = map(i -> Path(), 1:N)
    collision_table = []
    used_cnt_table = fill(0, K)

    for (k, i) in enumerate(planning_order)
        verbose(
            VERBOSE,
            1,
            deadline,
            "$(k)/$(N)\tagent-$(i) starts planning";
            CR = true,
            LF = false,
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
        h_func_i_tiebreak = (v) -> h_func_i(v) + used_cnt_table[v] * avoid_duplicates_weight

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
            VERBOSE > 0 && print("\n")
            verbose(VERBOSE, 1, deadline, "agent-$(i) fails to find a path")
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

    VERBOSE > 0 && print("\n")
    verbose(VERBOSE, 1, deadline, "finish prioritized planning")

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
        verbose(VERBOSE, 1, deadline, "iter-$(iter_cnt) starts")
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

function gen_invalid_pp(
    i::Int,
    starts::Config,
    goals::Config,
    collision_table::Vector,
    avoid_starts::Bool,
    avoid_goals::Bool,
)::Function
    return (S_from, S_to) -> begin
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
            collision_table[t][v_i_from] == collision_table[t-1][v_i_to] != NONE &&
                return true
        elseif !isempty(collision_table)
            collision_table[end][v_i_to] != NONE && return true
        end
        return false
    end
end

function PP_refine(
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
    avoid_duplicates_weight::Real = 0.01,
    planning_order::Vector{Int} = collect(1:length(starts)),
    repetition::Int = 3,
    VERBOSE::Int = 0,
    kwargs...,
)::Union{Nothing,Paths}

    N = length(starts)
    K = length(G)

    paths = map(i -> Path(), 1:N)
    collision_table = []
    used_cnt_table = fill(0, K)

    for _ = 1:repetition
        for (k, i) in enumerate(planning_order)
            # update collision_table & used_cnt_table
            score = typemax(Int)
            if !isempty(paths[i])
                score = 0
                for (t, v) in enumerate(paths[i])
                    used_cnt_table[v] > 1 && (score += 1)
                    used_cnt_table[v] -= 1
                    collision_table[t][v] = NONE
                end
                for t = (length(paths[i])+1):length(collision_table)
                    collision_table[t][paths[i][end]] = NONE
                end
            end

            verbose(
                VERBOSE,
                1,
                deadline,
                "$(k)/$(N)\tagent-$(i) starts planning";
                CR = true,
                LF = false,
            )
            invalid =
                gen_invalid_pp(i, starts, goals, collision_table, avoid_starts, avoid_goals)
            h_func_i = (v) -> h_func(i)(v) + used_cnt_table[v] * avoid_duplicates_weight
            path = timed_pathfinding(
                G = G,
                start = starts[i],
                check_goal = gen_check_goal_pp(paths, i, goals[i]),
                invalid = invalid,
                h_func = h_func_i,
                deadline = deadline,
                timestep_limit = timestep_limit,
            )

            # failure case
            if isnothing(path)
                VERBOSE > 0 && print("\n")
                verbose(VERBOSE, 1, deadline, "agent-$(i) fails to find a path")
                return nothing
            end

            updated_score = count(map(v -> used_cnt_table[v] > 0, path))

            # register
            updated_score < score && (paths[i] = path)

            # update collision table
            for (t, v) in enumerate(paths[i])
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
            for t = length(paths[i]):length(collision_table)
                collision_table[t][paths[i][end]] = i
            end
        end
        VERBOSE == 1 && println()
        verbose(
            VERBOSE,
            1,
            deadline,
            "duplicated vertices: $(length(filter(k -> k > 1, used_cnt_table)))",
        )
    end

    VERBOSE == 0 && println()
    verbose(VERBOSE, 1, deadline, "finish prioritized planning")

    return paths
end
