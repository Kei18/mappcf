History = Vector{@NamedTuple {config::Config, crashes::Vector{Crash}}}

function is_crashed(crashes::Vector{SyncCrash}, who::Int, when::Int)::Bool
    return any(crash -> crash.who == who && crash.when <= when, crashes)
end

function is_finished(
    config::Config,
    crashes::Vector{SyncCrash},
    goals::Config,
    when::Int,
)::Bool
    return all(i -> is_crashed(crashes, i, when) || config[i] == goals[i], 1:length(config))
end

function execute_with_local_FD(
    ins::SyncInstance,
    solution::Union{Nothing,Solution};
    crashes = Vector{SyncCrash}(),
    max_makespan::Int = 30,
    failure_prob::Real = 0,
    VERBOSE::Int = 0,
)::Union{History,Nothing}

    isnothing(solution) && return nothing
    N = length(ins.goals)
    plan_id_list = fill(1, N)
    config = copy(ins.starts)
    hist = History()

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
                plan = solution[i][plan_id_list[i]]
                v_next = get_in_range(plan.path, t + 1)

                # no crash at next position?
                crash_index = findfirst(c -> c.loc == v_next && c.when <= t, crashes)
                isnothing(crash_index) && break
                crash = crashes[crash_index]

                # find backup path
                backup_keys = collect(keys(plan.backup))
                backup_index = findfirst(
                    c -> c.when < t + 1 && c.loc == v_next && c.who == crash.who,
                    backup_keys,
                )

                # no backup path -> failure
                if isnothing(backup_index)
                    VERBOSE > 0 &&
                        @warn("agent-$i has no backup path for $crash at timestep-$t")
                    return nothing
                end

                next_plan_id = plan.backup[backup_keys[backup_index]]
                # check eternal loop
                @assert(plan_id_list[i] != next_plan_id, "invalid transition")
                plan_id_list[i] = next_plan_id
            end
        end

        # update config
        for i = 1:N
            is_crashed(crashes, i, t) && continue
            v_now = config[i]
            v_next = get_in_range(solution[i][plan_id_list[i]].path, t + 1)
            @assert(
                v_next == v_now || v_next in get_neighbors(ins.G, v_now),
                "invalid move"
            )
            config[i] = v_next
        end
        emulate_crashes!(
            config,
            crashes,
            t + 1,
            failure_prob = failure_prob,
            VERBOSE = VERBOSE,
        )
        push!(hist, (config = copy(config), crashes = copy(crashes)))

        # check collisions
        for i = 1:N, j = i+1:N
            v_i_from = hist[end-1].config[i]
            v_i_to = hist[end].config[i]
            v_j_from = hist[end-1].config[j]
            v_j_to = hist[end].config[j]
            @assert(
                v_i_from != v_j_from && (v_i_from != v_j_to || v_i_to != v_j_from),
                "collisions"
            )
        end

        # check termination
        if is_finished(config, crashes, ins.goals, t)
            VERBOSE > 0 && @info("finish execution")
            return hist
        end
    end

    VERBOSE > 0 && @warn("reaching max_makespan:$max_makespan")
    return nothing
end

function emulate_crashes!(
    config::Config,
    crashes::Vector{SyncCrash},
    timestep::Int;
    failure_prob::Real = 0.2,
    VERBOSE::Int = 0,
)::Nothing
    failure_prob == 0 && return
    N = length(config)
    for i = 1:N
        is_crashed(crashes, i, timestep) && continue
        if rand() < failure_prob
            VERBOSE > 0 && @info(@sprintf("agent-%d is crashed at loc-%d", i, config[i]))
            push!(crashes, SyncCrash(who = i, when = timestep, loc = config[i]))
        end
    end
end


function is_colliding(C1::Config, C2::Config)::Bool
    N = length(C1)
    for i = 1:N, j = i+1:N
        (C2[i] == C2[j] || (C1[i] == C2[j] && C2[i] == C1[j])) && return true
    end
    return false
end

# function sequential_execute(
#     G::Graph,
#     starts::Config,
#     goals::Config,
#     solution;
#     crashes = Crashes(),
#     failure_prob::Real = 0,
#     max_activation::Int = 10,
#     VERBOSE::Int = 0,
# )::Union{History,Nothing}
#     return nothing
# end


function approx_verification(
    ins::SyncInstance,
    solution::Solution;
    num_repetition::Int = 20,
    failure_prob::Real = 0.1,
    max_makespan::Int = 30,
)::Bool
    return isnothing(solution) || all(
        k ->
            !isnothing(
                execute_with_local_FD(
                    ins,
                    solution;
                    failure_prob = failure_prob,
                    max_makespan = max_makespan,
                ),
            ),
        1:num_repetition,
    )
end
