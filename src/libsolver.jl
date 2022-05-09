CriticalSection = @NamedTuple {when::Int, who::Int, loc::Int}
CriticalSections = Vector{CriticalSection}
SolutionEntry =
    @NamedTuple {path::Path, backup::Dict{CriticalSection,Int}, time_offset::Int}
Solution = Vector{Vector{SolutionEntry}}

function identify_critical_sections(
    paths::Paths,  # [agent] -> [time] -> location
    time_offset::Int = 1,
)::Vector{CriticalSections}
    N = length(paths)
    critical_sections = map(i -> [], 1:N)
    table = Dict()   # vertex => [ (who, when) ]
    for (i, path) in enumerate(paths)
        for t_i = time_offset:length(path)
            v_i = path[t_i]
            # new critical section is found
            for (j, t_j) in get!(table, v_i, [])
                j == i && continue
                if t_j < t_i
                    push!(critical_sections[i], (when = t_i, who = j, loc = v_i))
                elseif t_i < t_j
                    push!(critical_sections[j], (when = t_j, who = i, loc = v_i))
                end
            end
            # register new entry
            push!(table[v_i], (i, t_i))
        end
    end
    return critical_sections
end

function identify_critical_sections2(paths::Paths)
    critical_sections = Dict{Crash,Vector}()
    table = Dict()   # vertex => [ (who, when) ]
    for (i, path) in enumerate(paths)
        for t_i = 1:length(path)
            loc = path[t_i]
            # new critical section is found
            for (j, t_j) in get!(table, loc, [])
                j == i && continue
                if t_j < t_i
                    crash = Crash(when = t_j, who = j, loc = loc)
                    get!(critical_sections, crash, [])
                    push!(
                        critical_sections[crash],
                        (when = t_i - 1, who = i, observation_loc = paths[i][t_i-1]),
                    )
                elseif t_i < t_j
                    crash = Crash(when = t_i, who = i, loc = loc)
                    get!(critical_sections, crash, [])
                    push!(
                        critical_sections[crash],
                        (when = t_j - 1, who = j, observation_loc = paths[j][t_j-1]),
                    )
                end
            end
            # register new entry
            push!(table[loc], (i, t_i))
        end
    end
    return critical_sections
end

function identify_critical_sections2(paths::Paths, crashes)
    # TODO: optimize these procedure
    critical_sectinos = identify_critical_sections2(paths)
    crashed_agents = map(c -> c.who, crashes)

    # remove crashed agents
    filter!(e -> !(e[1].who in crashed_agents), critical_sectinos)

    # remove observations by crashed agents
    foreach(e -> filter!(o -> !(o.who in crashed_agents), e[2]), critical_sectinos)
    filter!(e -> !isempty(e[2]), critical_sectinos)

    return critical_sectinos
end

function print_solution(solution)::Nothing
    if isnothing(solution)
        @info "solution not found"
        return
    end
    @printf("solution:\n")
    for i = 1:length(solution)
        i > 1 && println()
        @printf("agent-%d\n", i)
        for (k, (path, backup, time_offset)) in enumerate(solution[i])
            @printf("%d => %s, %s\n", k, path[1:time_offset], path[time_offset+1:end])
            for b in sort(backup, by = (e) -> e.when)
                @printf("\t%s\n", b)
            end
        end
    end
end

function simple_solver2(
    G::Graph,
    starts::Config,
    goals::Config;
    max_makespan::Union{Nothing,Int} = 20,
)::Union{Nothing,Solution}

    # number of agents
    N = length(starts)

    # compute distance tables
    dist_tables = map(g -> get_distance_table(G, g), goals)

    # setup initial search node
    primary_paths = prioritized_planning(
        G,
        starts,
        goals;
        dist_tables = dist_tables,
        align_length = false,
    )
    isnothing(primary_paths) && return nothing

    # outcome
    solution = map(
        i -> [(
            path = primary_paths[i],
            backup = Dict{CriticalSection,Int}(),
            time_offset = 1,
        )],
        1:N,
    )

    # store all search nodes, working as queue
    OPEN = [(indexes = fill(1, N), crashes = [])]  # plan-index for each agent

    # BFS
    while !isempty(OPEN)
        # pop one search node
        (S, crashes) = popfirst!(OPEN)

        # retrieve info
        paths = map(k -> copy(solution[k][S[k]].path), 1:N)

        correct_agents = collect(1:N)
        for crash in crashes
            # remove from correct agents
            correct_agents = filter(i -> i != crash.who, correct_agents)
            # find appropriate t
            t = min(crash.when - 1, length(paths[crash.who]))
            while paths[crash.who][t] != crash.loc && t > 0
                t -= 1
            end
            paths[crash.who][t:end] = fill(crash.loc, length(paths[crash.who]) - t + 1)
        end
        time_offset = maximum(map(k -> solution[k][S[k]].time_offset, 1:N))

        # identify critical sections
        critical_sections_all_agents = identify_critical_sections(paths, time_offset)

        # branching
        for i = 1:N, critical_section in critical_sections_all_agents[i]
            j = critical_section.who
            t = critical_section.when
            loc = critical_section.loc

            # reformulate paths
            paths_from_middle = map(path -> path[t-1:end], paths)
            # crashed agent
            paths_from_middle[j] = fill(loc, length(paths_from_middle[j]))

            backup_path_i = single_agent_pathfinding(
                G,
                paths_from_middle,
                i,
                paths_from_middle[i][1],
                goals;
                max_makespan = isnothing(max_makespan) ? max_makespan :
                               max_makespan - t + 2,
                h_func = (v) -> dist_tables[i][v],
                correct_agents = filter(i -> i != j, correct_agents),
            )
            isnothing(backup_path_i) && return nothing

            # register backup path
            new_path_i = vcat(paths[i][1:t-2], backup_path_i)
            # update solution
            push!(
                solution[i],
                (
                    path = new_path_i,
                    backup = Dict{SolutionEntry,Int}(),
                    time_offset = t - 1,
                ),
            )
            # register children id
            solution[i][S[i]].backup[(when = t - 1, who = j, loc = loc)] =
                length(solution[i])

            # add new search node
            push!(
                OPEN,
                (
                    indexes = map(k -> (k == i) ? length(solution[i]) : S[k], 1:N),
                    crashes = vcat(copy(crashes), critical_section),
                ),
            )

        end
    end

    return solution
end


function simple_solver3(
    G::Graph,
    starts::Config,
    goals::Config;
    max_makespan::Union{Nothing,Int} = 20,
)

    # number of agents
    N = length(starts)

    # compute distance tables
    dist_tables = map(g -> get_distance_table(G, g), goals)

    # setup initial search node
    primary_paths = prioritized_planning(
        G,
        starts,
        goals;
        dist_tables = dist_tables,
        align_length = false,
        max_makespan = max_makespan,
    )
    isnothing(primary_paths) && return nothing

    # outcome
    solution = map(
        i -> [(path = primary_paths[i], backup = Dict{Crash,Int}(), time_offset = 1)],
        1:N,
    )

    # store all search nodes, working as queue
    OPEN = [(indexes = fill(1, N), crashes = [])]  # plan-index for each agent

    # BFS
    loop_cnt = 0
    while !isempty(OPEN)
        loop_cnt += 1

        # pop one search node
        indexes, known_crashes = popfirst!(OPEN)

        # retrieve paths
        paths = map(k -> copy(solution[k][indexes[k]].path), 1:N)
        foreach(c -> paths[c.who] = paths[c.who][1:c.when], known_crashes)  # crashed agents

        # identify critical sections
        critical_sections = identify_critical_sections2(paths, known_crashes)

        # branching
        for crash in sort(collect(keys(critical_sections)), by = (c) -> c.when)

            new_indexes = copy(indexes)
            observations = sort(critical_sections[crash], by = (o) -> o.when)

            # reformulate paths
            paths_with_crash = copy(paths)
            paths_with_crash[crash.who] = paths_with_crash[crash.who][1:crash.when]  # crashed agents

            # identify agents that require re-planning
            replanning_agents = []
            for o in observations
                backup = solution[o.who][indexes[o.who]].backup
                if haskey(backup, crash)
                    # already planned
                    backup_plan_id = backup[crash]
                    paths_with_crash[o.who] = copy(solution[o.who][backup_plan_id].path)
                    new_indexes[o.who] = backup_plan_id
                else
                    # re-planning required
                    paths_with_crash[o.who] = paths_with_crash[o.who][1:o.when]
                    push!(replanning_agents, o.who)
                end
            end

            # check collisions, TODO: delete later
            for i = 1:N
                i in replanning_agents && continue
                for t = 2:length(paths_with_crash[i])
                    v_i_from = paths_with_crash[i][t-1]
                    v_i_to = paths_with_crash[i][t]
                    for j = i+1:N
                        j in replanning_agents && continue
                        v_j_from =
                            paths_with_crash[j][min(t - 1, length(paths_with_crash[j]))]
                        v_j_to = paths_with_crash[j][min(t, length(paths_with_crash[j]))]
                        if v_j_to == v_i_to || (v_j_from == v_i_to && v_j_to == v_i_from)
                            @info "inconsistent plan"
                            println("known_crashes: $(known_crashes)")
                            println("new crash: $crash")
                            println("original paths: $paths")
                            println("paths with_crashes: $paths_with_crash")
                            println("observations: $observations")
                            println("replanning agents: $replanning_agents")
                            println(i, ",", j)
                            return nothing
                        end
                    end
                end
            end

            # re-planning
            for o in filter(o -> o.who in replanning_agents, observations)
                crashed_agents = map(c -> c.who, vcat(known_crashes, crash))
                correct_agents = filter(k -> !(k in crashed_agents), 1:N)

                # preliminary for single-agent pathfinding
                invalid =
                    (S_from, S_to) -> begin
                        # prohibit to use other goal
                        v_i_from = S_from.v
                        v_i_to = S_to.v
                        t = S_to.t + o.when - 1
                        !isnothing(max_makespan) && t > max_makespan && return true

                        # prohibit vertex or edge collision
                        for j = 1:N
                            j == o.who && continue
                            l = length(paths_with_crash[j])
                            # will be re-planed -> skip
                            t > l &&
                                j in replanning_agents &&
                                paths_with_crash[j] != goals[j] &&
                                continue
                            # avoid collisions
                            v_j_from = paths_with_crash[j][min(t - 1, l)]
                            v_j_to = paths_with_crash[j][min(t, l)]
                            (
                                v_i_to == v_j_to ||
                                (v_j_from == v_i_to && v_j_to == v_i_from)
                            ) && return true
                        end

                        # avoid goals of others
                        any(j -> j != o.who && goals[j] == S_to.v, correct_agents) &&
                            return true

                        return false
                    end

                h_func = (v) -> dist_tables[o.who][v]

                check_goal =
                    (S) -> begin
                        S.v != goals[o.who] && return false
                        for j = 1:N
                            j == o.who && continue
                            any(
                                t -> paths_with_crash[j][t] == S.v,
                                (o.when+S.t):length(paths_with_crash[j]),
                            ) && return false
                        end
                        return true
                    end

                backup_path = find_timed_path(
                    G,
                    o.observation_loc,
                    check_goal;
                    invalid = invalid,
                    h_func = h_func,
                )
                if isnothing(backup_path)
                    @info("no solution")
                    return nothing
                end

                paths_with_crash[o.who] = vcat(paths_with_crash[o.who], backup_path[2:end])

                # update solution
                push!(
                    solution[o.who],
                    (path = paths_with_crash[o.who], backup = Dict(), time_offset = o.when),
                )
                solution[o.who][indexes[o.who]].backup[crash] = length(solution[o.who])
                new_indexes[o.who] = length(solution[o.who])
            end

            # insert OPEN
            push!(OPEN, (indexes = new_indexes, crashes = vcat(known_crashes, crash)))
        end
    end

    return solution
end
