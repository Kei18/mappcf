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
                j != i &&
                    t_j < t_i &&
                    push!(critical_sections[i], (when = t_i, who = j, loc = v_i))
            end
            # register new entry
            push!(table[v_i], (i, t_i))
        end
    end
    return critical_sections
end

function simple_solver2(
    G::Graph,
    starts::Config,
    goals::Config;
    max_makespan::Union{Nothing,Int} = 20,
)::Solution

    # number of agents
    N = length(starts)

    # compute distance tables
    dist_tables = map(g -> get_distance_table(G, g), goals)

    # setup initial search node
    primary_paths = prioritized_planning(G, starts, goals; dist_tables = dist_tables)
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
    OPEN = [(fill(1, N))]  # plan-index for each agent

    # BFS
    while !isempty(OPEN)
        # pop one search node
        S = popfirst!(OPEN)

        # retrieve info
        paths = map(k -> solution[k][S[k]].path, 1:N)
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
            paths_from_middle[j] =
                fill(paths_from_middle[j][1], length(paths_from_middle[j]))

            # find backup path
            backup_path_i = single_agent_pathfinding(
                G,
                paths_from_middle,
                i,
                paths_from_middle[i][1],
                goals[i];
                max_makespan = isnothing(max_makespan) ? max_makespan :
                               max_makespan - t + 2,
                h_func = (v) -> dist_tables[i][v],
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
            push!(OPEN, map(k -> (k == i) ? length(solution[i]) : S[k], 1:N))
        end
    end

    return solution
end
