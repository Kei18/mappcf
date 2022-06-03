# global failure detector
function planner2(
    ins::SyncInstance;
    multi_agent_path_planner::Function,
    VERBOSE::Int = 0,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    h_func = gen_h_func(ins),
    kwargs...,
)::Solution
    return flatten_recursive_solution(
        planner2(
            ins.G,
            ins.starts,
            ins.goals,
            multi_agent_path_planner;
            VERBOSE = VERBOSE,
            deadline = deadline,
            h_func = h_func,
            kwargs...,
        ),
    )
end

@kwdef mutable struct RecursiveSolution
    paths::Paths
    offset::Int
    backup::Dict{Crash,RecursiveSolution}
end

function planner2(
    G::Graph,
    starts::Config,
    goals::Config,
    multi_agent_path_planner::Function,
    crashes::Vector{Crash} = Vector{Crash}(),
    offset::Int = 1,
    parent_constrations::Vector{Effect} = Vector{Effect}();
    VERBOSE::Int = 0,
    deadline::Union{Nothing,Deadline} = nothing,
    h_func::Function = gen_h_func(G, goals),
    kwargs...,
)::Union{Nothing,RecursiveSolution}

    constraints = copy(parent_constrations)
    @label START_PLANNING
    # check time limit
    is_expired(deadline) && return nothing

    # compute collision-free paths
    paths = multi_agent_path_planner(
        G,
        starts,
        goals,
        crashes,
        constraints,
        offset;
        deadline = deadline,
        h_func = h_func,
        VERBOSE = VERBOSE - 1,
        kwargs...,
    )
    isnothing(paths) && return nothing

    # identify critical sections
    U = get_new_unresolved_events(paths, offset)
    # compute backup paths
    backup = Dict()
    for event in U
        # recursive call
        backup[event.crash] = planner2(
            G,
            map(path -> get_in_range(path, event.crash.when - offset + 1), paths),
            goals,
            multi_agent_path_planner,
            vcat(crashes, event.crash),
            event.crash.when,
            constraints;
            h_func = h_func,
            VERBOSE = VERBOSE,
            deadline = deadline,
            kwargs...,
        )
        # failed to find backup path
        if isnothing(backup[event.crash])
            # update constrains
            push!(constraints, event.effect)
            # re-planning
            @goto START_PLANNING
        end
    end
    return RecursiveSolution(paths = paths, offset = offset, backup = backup)
end

function flatten_recursive_solution(
    recursive_solution::RecursiveSolution,
)::Union{Nothing,Solution}
    isnothing(recursive_solution) && return nothing

    N = length(recursive_solution.paths)
    solution = map(i -> Vector{Plan}(), 1:N)

    f!(S, parent_id::Union{Nothing,Int} = nothing) = begin
        plan_id = length(solution[1]) + 1
        offset = S.offset
        for i = 1:N
            parent_path =
                isnothing(parent_id) ? Path() : solution[i][parent_id].path[1:offset-1]
            plan = Plan(
                id = plan_id,
                who = i,
                path = vcat(parent_path, S.paths[i]),
                offset = offset,
            )
            push!(solution[i], plan)
        end
        for (crash, backup_plan) in S.backup
            children_id = f!(backup_plan, plan_id)
            foreach(i -> solution[i][plan_id].backup[crash] = children_id, 1:N)
        end
        return plan_id
    end

    f!(recursive_solution)
    return solution
end

function get_new_unresolved_events(paths::Paths, offset::Int = 1)::Vector{Event}
    U = Vector{Event}()
    table = Dict()   # vertex => [ (who, when) ]
    for (i, path) in enumerate(paths), t_i = 1:length(path)
        v = path[t_i]
        # new critical section is found
        for (j, t_j) in get!(table, v, [])
            j == i && continue
            e = get_sync_event(; v = v, i = i, j = j, t_i = t_i, t_j = t_j, offset = offset)
            push!(U, e)
        end
        push!(table[v], (i, t_i))
    end
    return U
end
