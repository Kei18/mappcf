History = Vector{@NamedTuple {config::Config, crashes::Vector{Crash}}}

function is_crashed(crashes::Vector{SyncCrash}, who::Int, when::Int)::Bool
    return any(crash -> crash.who == who && crash.when <= when, crashes)
end

function is_crashed(crashes::Vector{SeqCrash}, who::Int, args...)::Bool
    return any(crash -> crash.who == who, crashes)
end

function is_finished(
    config::Config,
    crashes::Vector{SyncCrash},
    goals::Config,
    when::Int,
)::Bool
    return all(i -> is_crashed(crashes, i, when) || config[i] == goals[i], 1:length(config))
end

function is_finished(config::Config, crashes::Vector{SeqCrash}, goals::Config)::Bool
    return all(i -> is_crashed(crashes, i) || config[i] == goals[i], 1:length(config))
end

function is_colliding(C1::Config, C2::Config)::Bool
    N = length(C1)
    for i = 1:N, j = i+1:N
        (C2[i] == C2[j] || (C1[i] == C2[j] && C2[i] == C1[j])) && return true
    end
    return false
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

function execute(
    ins::Instance,
    solution::Union{Nothing,Solution},
    state_change!::Function,
    pre_determined_crashes::Vector{T} where {T<:Crash},
    ;
    max_makespan::Int = 30,
    failure_prob::Real = 0,
    VERBOSE::Int = 0,
)::Union{History,Nothing}

    isnothing(solution) && return nothing
    N = length(ins.goals)
    plan_id_list = fill(1, N)
    config = copy(ins.starts)
    crashes = copy(pre_determined_crashes)
    hist = History()

    # initial step
    emulate_crashes!(config, crashes, 1, failure_prob = failure_prob, VERBOSE = VERBOSE)
    push!(hist, (config = copy(config), crashes = copy(crashes)))

    for t = 1:max_makespan

        # state change
        res = state_change!(plan_id_list, solution, crashes, t)
        if !isnothing(res)
            VERBOSE > 0 && @info(res)
            return nothing
        end

        # update config
        for i = 1:N
            is_crashed(crashes, i, t) && continue
            v_now = config[i]
            v_next = get_in_range(solution[i][plan_id_list[i]].path, t + 1)
            @assert(
                v_next == v_now || v_next in get_neighbors(ins.G, v_now),
                "invalid move: agent-$i at timestep-$(t) from $(v_now) -> $(v_next)"
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
        @assert(
            !is_colliding(hist[end-1].config, hist[end].config),
            "collisions occur, something wrong"
        )

        # check termination
        if is_finished(config, crashes, ins.goals, t)
            VERBOSE > 0 && @info("finish execution")
            return hist
        end
    end

    VERBOSE > 0 && @warn("reaching max_makespan:$max_makespan")
    return nothing
end

function execute_with_local_FD(
    ins::SyncInstance,
    solution::Union{Nothing,Solution},
    crashes::Vector{SyncCrash} = Vector{SyncCrash}(),
    ;
    kwargs...,
)::Union{History,Nothing}

    state_change! =
        (
            plan_id_list::Vector{Int},
            solution::Solution,
            crashes::Vector{SyncCrash},
            t::Int,
        ) -> begin
            N = length(plan_id_list)

            for i = 1:N
                # skip crashed agents
                is_crashed(crashes, i, t) && continue

                # plan update
                while true
                    # retrieve current plan
                    plan = solution[i][plan_id_list[i]]
                    v_next = get_in_range(plan.path, t + 1)

                    # no crash at next position?
                    crash_index =
                        findfirst(c -> c.loc == v_next && c.when <= t, crashes)
                    isnothing(crash_index) && break
                    crash = crashes[crash_index]

                    # find backup path
                    backup_keys = collect(keys(plan.backup))
                    backup_index = findfirst(
                        c -> c.when < t + 1 && c.loc == v_next && c.who == crash.who,
                        backup_keys,
                    )
                    isnothing(backup_index) && return "no backup path"

                    next_plan_id = plan.backup[backup_keys[backup_index]]
                    # check eternal loop
                    plan_id_list[i] == next_plan_id && return "invalid transition"
                    plan_id_list[i] = next_plan_id
                end
            end
            nothing
        end

    return execute(ins, solution, state_change!, crashes; kwargs...)
end


function execute_with_global_FD(
    ins::SyncInstance,
    solution::Union{Nothing,Solution},
    crashes::Vector{SyncCrash} = Vector{SyncCrash}(),
    ;
    kwargs...,
)::Union{History,Nothing}

    state_change! =
        (
            plan_id_list::Vector{Int},
            solution::Solution,
            crashes::Vector{SyncCrash},
            t::Int,
        ) -> begin
            N = length(plan_id_list)
            for crash in filter(c -> c.when == t, crashes)
                for i = 1:N
                    # skip crashed agents
                    is_crashed(crashes, i, t) && continue

                    # retrieve current plan
                    plan = solution[i][plan_id_list[i]]
                    !haskey(plan.backup, crash) && continue

                    # update plan id
                    next_plan_id = plan.backup[crash]
                    plan_id_list[i] == next_plan_id && return "invalid transition"
                    plan_id_list[i] = next_plan_id
                end
            end
            nothing
        end

    return execute(ins, solution, state_change!, crashes; kwargs...)
end

function execute_with_local_FD(
    ins::SeqInstance,
    solution::Union{Nothing,Solution},
    pre_determined_crashes::Vector{SeqCrash} = Vector{SeqCrash}(),
    ;
    max_activation::Int = 30,
    VERBOSE::Int = 0,
)::Union{History,Nothing}

    isnothing(solution) && return nothing
    N = length(ins.goals)
    plan_id_list = fill(1, N)
    progress_indexes = fill(1, N)
    config = copy(ins.starts)
    crashes = Vector{SeqCrash}()
    hist = History()

    # initial step
    push!(hist, (config = copy(config), crashes = copy(crashes)))

    for _ = 1:max_activation
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

        while true
            # retrieve current plan
            plan = solution[i][plan_id_list[i]]
            t = progress_indexes[i]
            @assert(t + 1 <= length(plan.path), "invalid plan")
            v_next = plan.path[t+1]

            # state change
            crash_index = findfirst(c -> c.loc == v_next, crashes)
            isnothing(crash_index) && break
            crash = crashes[crash_index]
            if !haskey(plan.backup, crash)
                @warn("no backup plan")
                return nothing
            end
            next_plan_id = plan.backup[crash]
            @assert(plan_id_list[i] != next_plan_id, "invalid transition")
            plan_id_list[i] = next_plan_id
        end

        # update config
        progress_indexes[i] += 1
        v_now = config[i]
        v_next = solution[i][plan_id_list[i]].path[progress_indexes[i]]
        @assert(
            v_next == v_now || v_next in get_neighbors(ins.G, v_now),
            "invalid move: agent-$i at timestep-$(t) from $(v_now) -> $(v_next)"
        )
        config[i] = v_next

        # update crash
        crash_index = findfirst(c -> c.who == i && c.loc == v_next, pre_determined_crashes)
        !isnothing(crash_index) && push!(crashes, pre_determined_crashes[crash_index])

        push!(hist, (config = copy(config), crashes = copy(crashes)))

        # check collisions
        @assert(
            !is_colliding(hist[end-1].config, hist[end].config),
            "collisions occur, something wrong"
        )

        # check termination
        if is_finished(config, crashes, ins.goals)
            VERBOSE > 0 && @info("finish execution")
            return hist
        end
    end

    VERBOSE > 0 && @warn("reaching max_makespan:$max_makespan")
    return nothing
end

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
