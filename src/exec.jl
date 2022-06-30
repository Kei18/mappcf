History = Vector{@NamedTuple {config::Config, crashes::Vector{Crash}}}

function is_crashed(crashes::Vector{T} where {T<:Crash}, who::Int)::Bool
    return any(crash -> crash.who == who, crashes)
end

function is_finished(
    config::Config,
    crashes::Vector{T} where {T<:Crash},
    goals::Config,
)::Bool
    return all(i -> is_crashed(crashes, i) || config[i] == goals[i], 1:length(config))
end

# I know that macro is not so beautiful...
macro update_crashes_sync_model!()
    return esc(
        quote
            (crashes::Vector{SyncCrash}, config::Config) -> begin
                for c in scheduled_crashes
                    is_no_more_crash(ins, crashes) && continue
                    c.when != current_timestep + 1 && continue
                    crashes in scheduled_crashes && continue
                    isnothing(findfirst(i -> i == c.who && config[i] == c.loc, 1:N)) &&
                        continue
                    push!(crashes, c)
                end

                failure_prob == 0 && return
                for i = 1:N
                    is_no_more_crash(ins, crashes) && continue
                    is_crashed(crashes, i) && continue
                    rand() > failure_prob && continue
                    VERBOSE > 0 && @info(
                        @sprintf(
                            "agent-%d is crashed at loc-%d, timestep-%d",
                            i,
                            config[i],
                            current_timestep + 1
                        )
                    )
                    push!(
                        crashes,
                        SyncCrash(who = i, when = current_timestep + 1, loc = config[i]),
                    )
                end
            end
        end,
    )
end

function execute(
    ins::Ins,
    solution::Union{Failure,Solution},
    update_config!::Function,
    update_crashes!::Function,
    ;
    max_activation::Int = 30,
    VERBOSE::Int = 0,
)::Union{History,Nothing} where {Ins<:Instance}

    isa(solution, Failure) && return nothing

    config = copy(ins.starts)
    crashes = (Ins == SyncInstance) ? Vector{SyncCrash}() : Vector{SeqCrash}()
    hist = History()

    # initial step
    update_crashes!(crashes, config)
    push!(hist, (config = copy(config), crashes = copy(crashes)))

    for t = 1:max_activation
        # update configuration
        update_config!(config, crashes)
        update_crashes!(crashes, config)

        # update history
        push!(hist, (config = copy(config), crashes = copy(crashes)))

        # verification
        check_valid_transition(ins.G, hist[end-1].config, hist[end].config, t)

        # check termination
        if is_finished(config, crashes, ins.goals)
            VERBOSE > 0 && @info("finish execution at $(t)-th activation's")
            return hist
        end
    end

    VERBOSE > 0 && @warn("reaching at max_activation:$max_activation")
    return nothing
end

function execute_with_local_FD(
    ins::SyncInstance,
    solution::Union{Failure,Solution};
    scheduled_crashes::Vector{SyncCrash} = Vector{SyncCrash}(),
    failure_prob::Real = 0,
    max_activation::Int = 30,
    VERBOSE::Int = 0,
)::Union{History,Nothing}

    N = length(ins.goals)

    # will be updated via functions
    plan_id_list = fill(1, N)
    current_timestep = 0

    update_config! =
        (config::Config, crashes::Vector{SyncCrash}) -> begin
            current_timestep += 1
            for i = 1:N
                # skip crashed agents
                is_crashed(crashes, i) && continue

                # plan update
                while true
                    # retrieve current plan
                    plan = solution[i][plan_id_list[i]]
                    v_next = get_in_range(plan.path, current_timestep + 1)

                    # crash exists at next position?
                    crash = find_first_element(
                        c -> c.loc == v_next && c.when <= current_timestep,
                        crashes,
                    )
                    isnothing(crash) && break

                    # find backup path
                    backup_key = find_first_element(
                        c ->
                            c.when <= current_timestep &&
                                c.loc == v_next &&
                                c.who == crash.who,
                        collect(keys(plan.backup)),
                    )
                    @assert(
                        !isnothing(backup_key),
                        begin
                            VERBOSE > 0 && println(
                                "[no backup]\n" *
                                "plan: $(plan)\n" *
                                "current_timestep: $(current_timestep)\n" *
                                "v_next: $(v_next)\n" *
                                "crashes: $(crashes)",
                            )
                            "no backup path"
                        end
                    )
                    next_plan_id = plan.backup[backup_key]
                    @assert(plan_id_list[i] != next_plan_id, "invalid transition")
                    plan_id_list[i] = next_plan_id
                end
            end
            for (i, id) in enumerate(plan_id_list)
                is_crashed(crashes, i) && continue
                config[i] = get_in_range(solution[i][id].path, current_timestep + 1)
            end
        end

    return execute(
        ins,
        solution,
        update_config!,
        @update_crashes_sync_model!();
        max_activation = max_activation,
        VERBOSE = VERBOSE,
    )
end

function execute_with_global_FD(
    ins::SyncInstance,
    solution::Union{Failure,Solution};
    scheduled_crashes::Vector{SyncCrash} = Vector{SyncCrash}(),
    failure_prob::Real = 0,
    max_activation::Int = 30,
    VERBOSE::Int = 0,
)::Union{History,Nothing}

    N = length(ins.goals)

    # will be updated via functions
    plan_id_list = fill(1, N)
    current_timestep = 0

    update_config! =
        (config::Config, crashes::Vector{SyncCrash}) -> begin
            current_timestep += 1  # update time
            for crash in filter(c -> c.when == current_timestep, crashes)
                for i = 1:N
                    # skip crashed agents
                    is_crashed(crashes, i) && continue

                    # retrieve current plan
                    plan = solution[i][plan_id_list[i]]
                    !haskey(plan.backup, crash) && continue

                    # update plan id
                    next_plan_id = plan.backup[crash]
                    @assert(plan_id_list[i] != next_plan_id, "invalid transition")
                    plan_id_list[i] = next_plan_id
                end
            end
            for (i, id) in enumerate(plan_id_list)
                is_crashed(crashes, i) && continue
                config[i] = get_in_range(solution[i][id].path, current_timestep + 1)
            end
        end

    return execute(
        ins,
        solution,
        update_config!,
        @update_crashes_sync_model!();
        max_activation = max_activation,
        VERBOSE = VERBOSE,
    )
end

function execute_with_local_FD(
    ins::SeqInstance,
    solution::Union{Failure,Solution},
    ;
    scheduled_crashes::Vector{SeqCrash} = Vector{SeqCrash}(),
    max_activation::Int = 30,
    failure_prob::Real = 0,
    VERBOSE::Int = 0,
)::Union{History,Nothing}

    N = length(ins.goals)

    # will be updated via functions
    plan_id_list = fill(1, N)
    progress_indexes = fill(1, N)

    update_config! =
        (config::Config, crashes::Vector{SeqCrash}) -> begin
            # identify alive agents
            correct_agents, = get_correct_crashed_agents(N, crashes)
            alive_agents = filter!(
                i -> begin
                    path = solution[i][plan_id_list[i]].path
                    t = progress_indexes[i]
                    # agents at goals should be excluded
                    t >= length(path) && return false
                    # stationary motion should be excluded from the solution
                    @assert(path[t] != path[t+1], "stationary motion is included")
                    # next vertex should be unoccupied
                    any(j -> config[j] == path[t+1], correct_agents) && return false
                    return true
                end,
                correct_agents,
            )

            isempty(alive_agents) && return nothing

            # pickup one agent
            i = rand(alive_agents)

            # activate, state transition
            while true
                # retrieve current plan
                plan = solution[i][plan_id_list[i]]
                t = progress_indexes[i]
                @assert(t + 1 <= length(plan.path), "invalid plan")
                v_next = plan.path[t+1]

                # state change
                crash = find_first_element(c -> c.loc == v_next, crashes)
                isnothing(crash) && break
                @assert(haskey(plan.backup, crash), "no backup plan")
                next_plan_id = plan.backup[crash]
                @assert(plan_id_list[i] != next_plan_id, "invalid transition")
                plan_id_list[i] = next_plan_id
            end

            # update configuration
            v_next = solution[i][plan_id_list[i]].path[progress_indexes[i]+1]
            if !(v_next in config)
                progress_indexes[i] += 1
                config[i] = v_next
            end
        end

    update_crashes! =
        (crashes::Vector{SeqCrash}, config::Config) -> begin
            for c in scheduled_crashes
                is_no_more_crash(ins, crashes) && continue
                config[c.who] != c.loc && continue
                c in crashes && continue
                isnothing(findfirst(i -> i == c.who && config[i] == c.loc, 1:N)) &&
                    continue
                push!(crashes, c)
            end

            failure_prob == 0 && return
            for i = 1:N
                is_no_more_crash(ins, crashes) && continue
                is_crashed(crashes, i) && continue
                rand() > failure_prob && continue
                VERBOSE > 0 && @info("agent-$i is crashed at vertex-$(config[i])")
                push!(crashes, SeqCrash(who = i, loc = config[i]))
            end
        end

    return execute(
        ins,
        solution,
        update_config!,
        update_crashes!;
        max_activation = max_activation,
        VERBOSE = VERBOSE,
    )
end

function approx_verify(
    exec::Function,
    ins::Instance,
    solution::Union{Failure,Solution};
    num_repetition::Int = 20,
    VERBOSE::Int = 0,
    kwargs...,
)::Bool

    isa(solution, Failure) && return true

    try
        for _ = 1:num_repetition
            res = exec(ins, solution; VERBOSE = VERBOSE - 1, kwargs...)
            isnothing(res) && return false
        end
        return true
    catch e
        @warn(e)
        return false
    end
end

function approx_verify_with_local_FD(args...; kwargs...)::Bool
    approx_verify(execute_with_local_FD, args...; kwargs...)
end

function approx_verify_with_global_FD(args...; kwargs...)::Bool
    approx_verify(execute_with_global_FD, args...; kwargs...)
end
