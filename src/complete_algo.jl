# not complete yet
function complete_algorithm(
    G::Graph,
    starts::Config,
    goals::Config;
    crashes = Crashes(),
    time_offset::Int = 1,
    VERBOSE::Int = 0,
)
    N = length(starts)

    # find collision free paths
    paths = astar_operator_decomposition(G, starts, goals, map(c -> c.who, crashes))
    if isnothing(paths)
        VERBOSE > 0 && @info("low-level search failure\n$(crashes)")
        return nothing
    end

    # identify critical sections
    critical_crashes = identify_critical_crashes(paths, crashes, time_offset)

    backups = Dict()
    for new_crash in critical_crashes
        backup = complete_algorithm(
            G,
            map(
                i -> paths[i][min(new_crash.when - time_offset + 1, length(paths[i]))],
                1:N,
            ),
            goals;
            crashes = vcat(crashes, new_crash),
            time_offset = new_crash.when,
            VERBOSE = VERBOSE,
        )
        isnothing(backup) && return nothing
        backups[new_crash] = backup
    end

    return (paths = paths, time_offset = time_offset, backups = backups)
end


function identify_critical_crashes(
    paths::Paths,
    crashes::Crashes = Crashes(),
    time_offset::Int = 1,
)::Crashes

    critical_sections = []
    table = Dict()   # vertex => [ (who, when) ]
    for (i, path) in enumerate(paths)
        for t_i = 1:length(path)
            loc = path[t_i]
            # new critical section is found
            for (j, t_j) in get!(table, loc, [])
                j == i && continue
                if t_j < t_i
                    push!(
                        critical_sections,
                        Crash(when = t_j + time_offset - 1, who = j, loc = loc),
                    )
                elseif t_i < t_j
                    push!(
                        critical_sections,
                        Crash(when = t_i + time_offset - 1, who = i, loc = loc),
                    )
                end
            end
            # register new entry
            push!(table[loc], (i, t_i))
        end
    end
    return critical_sections
end
