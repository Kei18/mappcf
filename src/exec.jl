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

function synchronous_execute(
    G::Graph,
    solution::Solution,
    goals::Config;
    crashes = Crashes(),
    failure_prob::Real = 0,
    max_makespan::Int = 10,
    VERBOSE::Int = 0,
)::History

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
            is_crashed(crashes, i, t) && continue

            # plan update
            while true
                # retrieve current plan
                plan = solution[i][state_ids[i]]
                loc_next = plan.path[t+1]

                # switch plan if matched
                plan_update = false
                for (cs, next_plan_id) in plan.backup
                    (cs.when != t || cs.loc != loc_next) && continue
                    !non_anonymous_failure_detector(crashes, loc_next, cs.who) && continue
                    # check eternal loop
                    @assert(state_ids[i] != next_plan_id, "invalid transition")
                    state_ids[i] = next_plan_id
                    plan_update = true
                    break
                end
                !plan_update && break
            end
        end

        # update config
        for i = 1:N
            is_crashed(crashes, i, t) && continue
            loc_now = config[i]
            loc_next = solution[i][state_ids[i]].path[t+1]
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
            break
        end
    end

    return hist
end
