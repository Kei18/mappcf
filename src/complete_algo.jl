# sync, global failure detector
function complete_algorithm(
    G::Graph,
    starts::Config,
    goals::Config;
    crashes = Crashes(),
    time_offset::Int = 1,
    VERBOSE::Int = 0,
    parent_constrations = [],
    mapf_planner::Function = astar_operator_decomposition,  # MAPF algorithm
)
    constraints = copy(parent_constrations)
    @label start_planning
    # compute collision-free paths
    paths = mapf_planner(G, starts, goals, crashes, constraints, time_offset)
    # planning failure
    isnothing(paths) && return nothing
    # identify critical sections
    critical_sections = identify_critical_sections5(paths, crashes, time_offset)
    # compute backup paths
    backups = Dict()
    for (crash, effect) in critical_sections
        # recursive call
        backups[crash] = complete_algorithm(
            G,
            map(p -> get_in_range(p, crash.when - time_offset + 1), paths),   # new starts
            goals;
            crashes = vcat(crashes, crash),
            time_offset = crash.when,
            parent_constrations = constraints,
            VERBOSE = VERBOSE,
        )
        # failed to find backup path
        if isnothing(backups[crash])
            # update constrains
            push!(constraints, effect)
            # re-planning
            @goto start_planning  # I hate goto statement but useful...
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


function print_solution_global_FD(solution, depth = 0)
    N = length(solution.paths)
    print("\t"^depth, " t: ")
    T = maximum(length, solution.paths)
    foreach(t -> @printf("%3d    ", t), 1:T)
    println("\n", "\t"^depth, "--:", ("-"^7)^T)

    for (i, path) in enumerate(solution.paths)
        print("\t"^depth)
        @printf("%2d: %s", i, "       "^(solution.time_offset - 1))
        foreach(v -> @printf("%3d -> ", v), path)
        println()
    end
    for (crash, backup_plan) in solution.backups
        println("\n", "\t"^(depth + 1), crash)
        print_solution_global_FD(backup_plan, depth + 1)
    end
end
