# not complete yet
function complete_algorithm(
    G::Graph,
    starts::Config,
    goals::Config;
    crashes = Crashes(),
    time_offset::Int = 1,
    VERBOSE::Int = 0,
    parent_constrations = [],
)
    N = length(starts)
    constraints = copy(parent_constrations)

    replanning_flg = true
    backups = Dict()
    paths = Paths()
    while replanning_flg
        replanning_flg = false

        # find collision free paths
        paths = astar_operator_decomposition(
            G,
            starts,
            goals,
            map(c -> c.who, crashes),
            constraints,
            time_offset,
        )
        if isnothing(paths)
            s = "low-level search failure\n"
            s *= "crashes: $(crashes)\n"
            s *= "constraints: $(constraints)\n"
            s *= "starts: $(starts)\n"
            s *= "time_offset:$(time_offset)"
            VERBOSE > 0 && @info(s)
            return nothing
        end

        # identify critical sections
        critical_sections = identify_critical_sections5(paths, crashes, time_offset)

        for (crash, effect) in critical_sections
            backup = complete_algorithm(
                G,
                map(
                    i -> paths[i][min(crash.when - time_offset + 1, length(paths[i]))],
                    1:N,
                ),
                goals;
                crashes = vcat(crashes, crash),
                time_offset = crash.when,
                parent_constrations = constraints,
                VERBOSE = VERBOSE,
            )
            if isnothing(backup)  # re-planning
                push!(constraints, effect)
                replanning_flg = true
                backups = Dict()
                break
            end
            backups[crash] = backup
        end
    end

    return (paths = paths, time_offset = time_offset, backups = backups)
end


function identify_critical_sections5(
    paths::Paths,
    crashes::Crashes = Crashes(),
    time_offset::Int = 1,
)

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
                        (
                            crash = Crash(when = t_j + time_offset - 1, who = j, loc = loc),
                            effect = (when = t_i + time_offset - 1, who = i, loc = loc),
                        ),
                    )
                elseif t_i < t_j
                    push!(
                        critical_sections,
                        (
                            crash = Crash(when = t_i + time_offset - 1, who = i, loc = loc),
                            effect = (when = t_j + time_offset - 1, who = j, loc = loc),
                        ),
                    )
                end
            end
            # register new entry
            push!(table[loc], (i, t_i))
        end
    end
    return critical_sections
end
