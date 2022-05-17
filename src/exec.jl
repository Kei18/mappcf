@kwdef struct Crash
    when::Int  # timestep
    who::Int   # agent index
    loc::Int   # location index
end
Crashes = Vector{Crash}
Base.show(io::IO, c::Crash) = print(io, "Crash(when=$(c.when), who=$(c.who), loc=$(c.loc))")

History = Vector{@NamedTuple {config::Config, crashes::Crashes}}

function is_neighbor(G::Graph, config::Config, agent::Int, target_loc::Int)::Bool
    return target_loc in get_neighbors(G, config[agent])
end

function is_crashed(crashes::Crashes, agent::Int, t::Int)::Bool
    return any(crash -> crash.who == agent && crash.when <= t, crashes)
end

function is_occupied(config::Config, target_loc::Int)::Bool
    return target_loc in config
end

function non_anonymous_failure_detector(
    crashes::Crashes,
    target_loc::Int,
    target_agent::Int,
)::Bool
    return any(crash -> crash.who == target_agent && crash.loc == target_loc, crashes)
end

function non_anonymous_failure_detector(crashes::Crashes, target_loc::Int)::Bool
    return any(crash.loc == target_loc, crashes)
end

function is_finished(config::Config, crashes::Crashes, goals::Config, t::Int)::Bool
    return all(i -> is_crashed(crashes, i, t) || config[i] == goals[i], 1:length(config))
end

function emulate_crashes!(
    config::Config,
    crashes::Crashes,
    timestep::Int;
    failure_prob::Real = 0.2,
    VERBOSE::Int = 0,
)::Nothing
    N = length(config)
    for i in filter(i -> !is_crashed(crashes, i, timestep), 1:N)
        if rand() < failure_prob
            loc_id = config[i]
            VERBOSE > 0 && @info(@sprintf("agent-%d is crashed at loc-%d", i, loc_id))
            push!(crashes, Crash(who = i, when = timestep, loc = loc_id))
        end
    end
end


function synchronous_global_execute(
    G::Graph,
    starts::Config,
    goals::Config,
    solution;
    crashes = Crashes(),
    failure_prob::Real = 0,
    max_makespan::Int = 10,
    VERBOSE::Int = 0,
)::Union{History,Nothing}

    N = length(goals)
    state_ids = fill(1, N)
    config = copy(starts)
    hist = History()

    VERBOSE > 0 && @info("start synchronous execution")
    # initial step
    emulate_crashes!(config, crashes, 1, failure_prob = failure_prob, VERBOSE = VERBOSE)
    push!(hist, (config = copy(config), crashes = copy(crashes)))

    plan = solution
    for t = 1:max_makespan
        # update plan
        for crash in filter(c -> c.when == t, crashes)
            if haskey(plan.backups, crash)
                plan = plan.backups[crash]
            end
        end
        # update config
        config_prev = copy(config)
        for i = 1:N
            is_crashed(crashes, i, t) && continue
            loc_now = config[i]
            path = plan.paths[i]
            loc_next = path[min(t - plan.time_offset + 2, length(path))]
            @assert(
                loc_next == loc_now || loc_next in get_neighbors(G, loc_now),
                "invalid move"
            )
            config[i] = loc_next
        end
        # check consistency
        for i = 1:N
            if config[i] != config_prev[i] &&
               !(config[i] in get_neighbors(G, config_prev[i]))
                VERBOSE > 0 && @warn(
                    "invalid execution, move for agent-$i from v-$(config[i]) to v-$(config_prev[i])"
                )
                return nothing
            end
            for j = i+1:N
                if config[i] == config[j] ||
                   (config[i] == config_prev[j] && config_prev[i] == config[j])
                    VERBOSE > 0 && @warn("invalid execution, collision between $i and $j")
                    return nothing
                end
            end
        end


        emulate_crashes!(config, crashes, t; failure_prob = failure_prob)
        push!(hist, (config = copy(config), crashes = copy(crashes)))

        # check termination
        if is_finished(config, crashes, goals, t)
            VERBOSE > 0 && @info("finish execution")
            return hist
        end
    end
end

function synchronous_execute(
    G::Graph,
    starts::Config,
    goals::Config,
    solution;
    crashes = Crashes(),
    failure_prob::Real = 0,
    max_makespan::Int = 10,
    VERBOSE::Int = 0,
)::Union{History,Nothing}

    N = length(goals)
    state_ids = fill(1, N)
    config = map(i -> solution[i][1].path[1], 1:N)
    hist = History()

    VERBOSE > 0 && @info("start synchronous execution")
    # initial step
    emulate_crashes!(config, crashes, 1, failure_prob = failure_prob, VERBOSE = VERBOSE)
    push!(hist, (config = copy(config), crashes = copy(crashes)))

    for t = 1:max_makespan
        # state change
        for i = 1:N
            # skip crashed agents
            is_crashed(crashes, i, t) && continue

            # plan update
            while true
                # retrieve current plan
                plan = solution[i][state_ids[i]]
                path = plan.path
                loc_next = path[min(t + 1, length(path))]

                # no crash at next position?
                crash_index = findfirst(c -> c.loc == loc_next && c.when <= t, crashes)
                isnothing(crash_index) && break
                crash = crashes[crash_index]

                # find backup path
                backup_keys = collect(keys(plan.backup))
                backup_index = findfirst(
                    c -> c.when < t + 1 && c.loc == loc_next && c.who == crash.who,
                    backup_keys,
                )

                # no backup path -> failure
                if isnothing(backup_index)
                    VERBOSE > 0 && @warn(
                        @sprintf(
                            "agent-%d has no backup path for %s at timestep-%d",
                            i,
                            crash,
                            t
                        )
                    )
                    return nothing
                end

                next_plan_id = plan.backup[backup_keys[backup_index]]
                # check eternal loop
                @assert(state_ids[i] != next_plan_id, "invalid transition")
                state_ids[i] = next_plan_id
            end
        end

        # update config
        for i = 1:N
            is_crashed(crashes, i, t) && continue
            loc_now = config[i]
            path = solution[i][state_ids[i]].path
            loc_next = path[min(t + 1, length(path))]
            @assert(
                loc_next == loc_now || loc_next in get_neighbors(G, loc_now),
                "invalid move"
            )
            config[i] = loc_next
        end
        emulate_crashes!(config, crashes, t; failure_prob = failure_prob)
        push!(hist, (config = copy(config), crashes = copy(crashes)))

        # check termination
        if is_finished(config, crashes, goals, t)
            VERBOSE > 0 && @info("finish execution")
            return hist
        end
    end

    VERBOSE > 0 && @warn(@sprintf("reaching max_makespan%d", max_makespan))
    return nothing
end

function sync_verification(
    G::Graph,
    starts::Config,
    goals::Config,
    solution;
    num_repetition::Int = 20,
    failure_prob::Real = 0.1,
    max_makespan::Int = 30,
)::Bool
    return isnothing(solution) || all(
        k ->
            !isnothing(
                synchronous_execute(
                    G,
                    starts,
                    goals,
                    solution;
                    failure_prob = failure_prob,
                    max_makespan = max_makespan,
                ),
            ),
        1:num_repetition,
    )
end
