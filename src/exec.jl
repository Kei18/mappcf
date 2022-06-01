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

function is_colliding(C1::Config, C2::Config)::Bool
    N = length(C1)
    for i = 1:N, j = i+1:N
        (C2[i] == C2[j] || (C1[i] == C2[j] && C2[i] == C1[j])) && return true
    end
    return false
end

function is_valid_move(G::Graph, v_from::Int, v_to::Int)::Bool
    return v_to == v_from || v_to in get_neighbors(G, v_from)
end

function check_colliding(C1::Config, C2::Config)::Nothing
    @assert(!is_colliding(C1, C2), "collisions occur")
end

function check_valid_move(G::Graph, v_from::Int, v_to::Int)::Nothing
    @assert(is_valid_move(G, v_from, v_to), "invalid move: from $(v_now) -> $(v_next)")
end

function check_valid_transition(G::Graph, C_from::Config, C_to::Config)
    N = length(C_from)
    for i = 1:N
        v_i_from = C_from[i]
        v_i_to = C_to[i]
        # move
        @assert(
            v_i_to == v_i_from || v_i_to in get_neighbors(G, v_i_from),
            "invalid move for agent-$i: from $(v_i_from) -> $(v_i_to)"
        )
        for j = i+1:N
            v_j_from = C_from[j]
            v_j_to = C_to[j]
            # check collisions
            @assert(
                v_j_from != v_i_from,
                "vertex collision between agent-$i and agent-$j at vertex-$(v_i_from)"
            )
            @assert(
                v_j_from != v_i_to || v_j_to != v_i_from,
                "edge collision between agent-$i and agent-$j at vertex [$v_i_from, $v_i_to]"
            )
        end
    end
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
    ins::Ins,
    solution::Union{Nothing,Solution},
    update_config!::Function,
    update_crashes!::Function,
    ;
    max_activation::Int = 30,
    failure_prob::Real = 0,
    VERBOSE::Int = 0,
)::Union{History,Nothing} where {Ins<:Instance}

    isnothing(solution) && return nothing

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
        check_valid_transition(ins.G, hist[end-1].config, hist[end].config)

        # check termination
        if is_finished(config, crashes, ins.goals)
            VERBOSE > 0 && @info("finish execution")
            return hist
        end
    end

    VERBOSE > 0 && @warn("reaching max_activation:$max_activation")
    return nothing
end

function execute_with_local_FD(
    ins::SyncInstance,
    solution::Union{Nothing,Solution},
    scheduled_crashes::Vector{SyncCrash} = Vector{SyncCrash}();
    kwargs...,
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
                    @assert(!isnothing(backup_key), "no backup path")
                    next_plan_id = plan.backup[backup_key]
                    @assert(plan_id_list[i] != next_plan_id, "invalid transition")
                    plan_id_list[i] = next_plan_id
                end
            end

            # update configuration
            for i = 1:N
                is_crashed(crashes, i) && continue
                config[i] = get_in_range(
                    solution[i][plan_id_list[i]].path,
                    current_timestep + 1,
                )
            end
        end

    update_crashes! =
        (crashes::Vector{SyncCrash}, config::Config) -> begin
            foreach(c -> c.when == current_timestep + 1 && push!(crashes, c), scheduled_crashes)
        end

    return execute(ins, solution, update_config!, update_crashes!; kwargs...)
end


function execute_with_global_FD(
    ins::SyncInstance,
    solution::Union{Nothing,Solution},
    scheduled_crashes::Vector{SyncCrash} = Vector{SyncCrash}();
    kwargs...,
)::Union{History,Nothing}

    N = length(ins.goals)
    plan_id_list = fill(1, N)
    current_timestep = 0

    update_config! =
        (config::Config, crashes::Vector{SyncCrash}) -> begin
            current_timestep += 1
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

            # update configuration
            for i = 1:N
                is_crashed(crashes, i) && continue
                config[i] = get_in_range(
                    solution[i][plan_id_list[i]].path,
                    current_timestep + 1,
                )
            end
        end

    update_crashes! =
        (crashes::Vector{SyncCrash}, config::Config) -> begin
            foreach(c -> c.when == current_timestep + 1 && push!(crashes, c), scheduled_crashes)
        end

    return execute(ins, solution, update_config!, update_crashes!; kwargs...)
end

function execute_with_local_FD(
    ins::SeqInstance,
    solution::Union{Nothing,Solution},
    scheduled_crashes::Vector{SeqCrash} = Vector{SeqCrash}(),
    ;
    max_activation::Int = 30,
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

            # update config
            progress_indexes[i] += 1
            v_next = solution[i][plan_id_list[i]].path[progress_indexes[i]]
            config[i] = v_next
        end

    update_crashes! =
        (crashes::Vector{SeqCrash}, config::Config) -> begin
            for c in scheduled_crashes
                config[c.who] == c.loc && !(c in crashes) && push!(crashes, c)
            end
        end

    return execute(ins, solution, update_config!, update_crashes!)
end

function approx_verification(
    ins::SyncInstance,
    solution::Solution;
    num_repetition::Int = 20,
    failure_prob::Real = 0.1,
    max_activation::Int = 30,
)::Bool

    isnothing(solution) && return true

    try
        for _ = 1:num_repetition
            res = execute_with_local_FD(
                ins,
                solution;
                failure_prob = failure_prob,
                max_activation = max_activation,
            )
            isnothing(res) && return false
        end
        return true
    catch e
        @warn(e)
        return false
    end
end
