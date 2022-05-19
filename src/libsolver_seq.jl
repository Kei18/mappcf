function seq_solver1(G::Graph, starts::Config, goals::Config; VERBOSE::Int = 0)
    # number of agents
    N = length(starts)

    # compute distance tables
    dist_tables = map(g -> get_distance_table(G, g), goals)
    primary_paths = seq_prioritized_planning(
        G,
        starts,
        goals;
        dist_tables = dist_tables,
        VERBOSE = VERBOSE - 1,
    )
    isnothing(primary_paths) && return nothing

    # outcome
    solution = map(i -> [(path = primary_paths[i], backup = Dict(), time_offset = 1)], 1:N)

    for i = 1:N

        # compute backup path
        Q = [(id = 1, crashes = [])]

        # set heuristics
        h_func = (v) -> dist_tables[i][v]

        while !isempty(Q)
            S = popfirst!(Q)
            # identify critical sections
            CS = identify_critical_sections6(
                i,
                solution[i][S.id].path,
                solution,
                S.crashes,
                solution[i][S.id].time_offset,
            )

            for (crash, o) in CS
                haskey(solution[i][S.id].backup, crash) && continue
            end
        end
    end

    return solution
end

function identify_critical_sections6(i, path, solution, crashes, time_offset)

    N = length(solution)

    # assumed to be used with prioritized planning
    critical_sections = []
    crashed_agents = map(c -> c.who, crashes)

    # create collision table
    table = Dict()
    for j = 1:N
        (j == i || j in crashed_agents) && continue
        for (path_j,) in solution[j]
            for t_j = 1:length(path_j)
                loc = path_j[t_j]
                get!(table, loc, [])
                push!(table[loc], (j, t_j))
            end
        end
    end

    # identify critical sections
    for (k, loc) in enumerate(path[time_offset+1:end])
        t_i = k + time_offset
        for (j, t_j) in get!(table, loc, [])
            crash = Crash(when = t_j, who = j, loc = loc)
            push!(
                critical_sections,
                (crash, (when = t_i - 1, who = i, observation_loc = path[t_i-1])),
            )
        end
    end

    return critical_sections
end
