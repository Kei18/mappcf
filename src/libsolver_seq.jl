function aggressive_search(G::Graph, starts::Config, goals::Config)
    # get initial solution
    solution = get_initial_solution(G, starts, goals)
    if isnothing(solution)
        @info("failed to find initial solution")
        return nothing
    end

    # identify intersections
    U = get_initial_unresolved_list(solution)

    while !isempty(U)
        # pop
        node = popfirst!(U)
        # compute backup paths
        (i, new_plan_id) = find_backup_path!(G, starts, goals, solution, node)
        # failure case
        if isnothing(new_plan_id)
            @warn(
                "failure, $(node), $(solution[node.effect.who][node.effect.plan_id].crashes)"
            )
            return solution
        end
        # append new intersections
        U = vcat(U, find_intersections(solution, i, new_plan_id))
    end
    return solution
end

function get_initial_solution(G::Graph, starts::Config, goals::Config)
    primary_paths = seq_prioritized_planning(G, starts, goals)
    isnothing(primary_paths) && return nothing
    return map(
        i -> [(path = primary_paths[i], offset = 1, crashes = [], backup = Dict())],
        1:length(starts),
    )
end

function get_initial_unresolved_list(solution)
    N = length(solution)
    U = []
    table = Dict()
    for i = 1:N, (t_i, v) in enumerate(solution[i][1].path)
        for (j, t_j) in get!(table, v, [])
            t_i > 1 && push!(
                U,
                (
                    crash = (who = j, loc = v),
                    effect = (who = i, when = t_i, loc = v, plan_id = 1),
                ),
            )
            t_j > 1 && push!(
                U,
                (
                    crash = (who = i, loc = v),
                    effect = (who = j, when = t_j, loc = v, plan_id = 1),
                ),
            )
        end
        push!(table[v], (i, t_i, 1))
    end
    return U
end

function find_backup_path!(G::Graph, starts::Config, goals::Config, solution, entry)
    # who
    i = entry.effect.who
    # when
    offset = entry.effect.when - 1
    # which plan
    original_plan_i = solution[i][entry.effect.plan_id]
    # new start & goal
    s = original_plan_i.path[offset]
    g = goals[i]
    # crashes must be handled
    crashes = vcat(original_plan_i.crashes, entry.crash)
    crashed_agents = map(c -> c.who, crashes)
    correct_agents = filter(j -> !(j in crashed_agents), 1:length(starts))
    correct_agents_goals = map(j -> goals[j], correct_agents)
    # constraints for backup path
    is_cyclic_deadlock = generate_cyclic_deadlock_detector(solution, i, crashes)
    invalid =
        (v_from, v_to) -> begin
            # avoid terminal deadlocks
            (v_to != g && v_to in correct_agents_goals) && return true
            # avoid cyclic deadlocks
            is_cyclic_deadlock(v_from, v_to) && return true
            # avoid crashed locations
            any(c -> c.loc == v_to, crashes) && return true
            return false
        end
    # find backup path
    new_path = astar_search(G, s, g; invalid = invalid)
    isnothing(new_path) && return (i, nothing)
    # create new backup plan
    new_plan = (
        path = vcat(original_plan_i.path[1:offset-1], new_path),
        offset = offset,
        crashes = crashes,
        backup = Dict(),
    )
    # register
    push!(solution[i], new_plan)
    new_plan_id = length(solution[i])
    solution[i][entry.effect.plan_id].backup[entry.crash] = new_plan_id

    return (i, new_plan_id)
end

function generate_cyclic_deadlock_detector(solution, i::Int, crashes)::Function

    T_f = Dict{}()  # from
    T_t = Dict{}()  # to
    register! = (t) -> begin
        get!(T_f, first(t.path), [])
        get!(T_t, last(t.path), [])
        push!(T_f[first(t.path)], t)
        push!(T_t[last(t.path)], t)
    end

    crashed_agents = map(c -> c.who, crashes)
    for j in filter(j -> j != i && !(j in crashed_agents), 1:length(solution))
        for plan_j in solution[j], k = 1:length(plan_j.path)-1
            u = plan_j.path[k]    # from
            v = plan_j.path[k+1]  # to

            # a fragment only with i
            fragment = (agents = [j], path = [u, v])
            register!(fragment)

            # (known fragment)->u->v
            for t in get!(T_t, u, [])
                j in t.agents && continue
                register!((agents = vcat(t.agents, j), path = vcat(t.path, v)))
            end

            # u->v->(known fragment)
            for t in get!(T_f, v, [])
                j in t.agents && continue
                register!((agents = vcat(j, t.agents), path = vcat(u, t.path)))
            end

            # (known fragment 1)->u->v->(known fragment 2)
            for t_t in T_t[u]
                j in t_t.agents && continue
                for t_f in T_f[v]
                    j in t_f.agents && continue
                    any(l -> l in t_t.agents, t_f.agents) && continue
                    register!((
                        agents = vcat(t_t.agents, j, t_f.agents),
                        path = vcat(t_t.path, t_f.path),
                    ))
                end
            end
        end
    end

    return (v_from, v_to) ->
        haskey(T_t, v_from) && any(t -> first(t.path) == v_to, T_t[v_from])
end

function find_intersections(solution, i::Int, plan_i_id::Int)

    plan_i = solution[i][plan_i_id]
    crashed_agents = map(c -> c.who, plan_i.crashes)

    table = Dict()
    for j in filter(j -> j != i && !(j in crashed_agents), 1:length(solution))
        for (plan_j_id, plan_j) in enumerate(solution[j])
            any(c -> c.who == i, plan_j.crashes) && continue
            for (t_j, v) in enumerate(plan_j.path)
                get!(table, v, [])
                push!(table[v], (j, t_j, plan_j_id))
            end
        end
    end

    U = []
    for t_i = plan_i.offset+1:length(plan_i.path)
        v = plan_i.path[t_i]
        for (j, t_j, plan_j_id) in get!(table, v, [])
            plan_j = solution[j][plan_j_id]
            inconsistent(plan_i.crashes, plan_j.crashes) && continue
            c_i = (who = i, loc = v)
            c_j = (who = j, loc = v)
            t_i > 1 &&
                !haskey(plan_i.backup, c_j) &&
                push!(
                    U,
                    (
                        crash = c_j,
                        effect = (who = i, when = t_i, loc = v, plan_id = plan_i_id),
                    ),
                )
            t_j > 1 &&
                !haskey(plan_j.backup, c_i) &&
                push!(
                    U,
                    (
                        crash = c_i,
                        effect = (who = j, when = t_j, loc = v, plan_id = plan_j_id),
                    ),
                )
        end
    end

    return U
end

function inconsistent(crashes_i, crashes_j)::Bool
    return any(
        e -> e[1].who == e[2].who && e[1].loc != e[2].loc,
        product(crashes_i, crashes_j),
    )
end

function create_fragment_tables(paths::Paths)

    N = length(paths)

    T_f = Dict{Int,Vector}()  # from
    T_t = Dict{Int,Vector}()  # to
    register! = (t) -> begin
        get!(T_f, first(t.path), [])
        get!(T_t, last(t.path), [])
        push!(T_f[first(t.path)], t)
        push!(T_t[last(t.path)], t)
    end

    for i = 1:N
        for k = 1:length(paths[i])-1
            u = paths[i][k]    # from
            v = paths[i][k+1]  # to

            # a fragment only with i
            fragment = (agents = [i], path = [u, v])
            register!(fragment)

            # (known fragment)->u->v
            for t in get!(T_t, u, [])
                i in t.agents && continue
                register!((agents = vcat(t.agents, i), path = vcat(t.path, v)))
            end

            # u->v->(known fragment)
            for t in get!(T_f, v, [])
                i in t.agents && continue
                register!((agents = vcat(i, t.agents), path = vcat(u, t.path)))
            end

            # (known fragment 1)->u->v->(known fragment 2)
            for t_t in T_t[u]
                i in t_t.agents && continue
                for t_f in T_f[v]
                    i in t_f.agents && continue
                    any(l -> l in t_t.agents, t_f.agents) && continue
                    register!((
                        agents = vcat(t_t.agents, i, t_f.agents),
                        path = vcat(t_t.path, t_f.path),
                    ))
                end
            end
        end
    end

    return (T_f, T_t)
end

function identify_critical_sections6(paths::Paths)
    critical_sections = []
    table = Dict()   # vertex => [ (who, when) ]
    for (i, path) in enumerate(paths)
        for t_i = 1:length(path)
            loc = path[t_i]
            # new critical section is found
            for (j, t_j) in get!(table, loc, [])
                j == i && continue
                t_i > 1 && push!(
                    critical_sections,
                    (
                        crash = Crash(when = t_j, who = j, loc = loc),
                        observation_from = (when = t_i - 1, who = i, loc = paths[i][t_i-1]),
                    ),
                )
                t_j > 1 && push!(
                    critical_sections,
                    (
                        crash = Crash(when = t_i, who = i, loc = loc),
                        observation_from = (when = t_j - 1, who = j, loc = paths[j][t_j-1]),
                    ),
                )
            end
            # register new entry
            push!(table[loc], (i, t_i))
        end
    end
    return critical_sections
end
