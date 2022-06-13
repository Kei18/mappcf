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
)::Union{Failure,Solution}
    res = planner2(
        ins,
        ins.starts,
        multi_agent_path_planner;
        VERBOSE = VERBOSE,
        deadline = deadline,
        h_func = h_func,
        kwargs...,
    )
    !isa(res, RecursiveSolution) && return res
    verbose(VERBOSE, 1, deadline, "flatten recursive solution")
    solution = flatten_recursive_solution(res)
    return solution
end

@kwdef mutable struct RecursiveSolution
    paths::Paths
    offset::Int
    backup::Dict{Crash,RecursiveSolution}
end

function planner2(
    ins::Instance,
    starts::Config,
    multi_agent_path_planner::Function,
    crashes::Vector{Crash} = Vector{Crash}(),
    offset::Int = 1,
    parent_constrations::Vector{Effect} = Vector{Effect}();
    VERBOSE::Int = 0,
    deadline::Union{Nothing,Deadline} = nothing,
    h_func::Function = gen_h_func(ins.G, ins.goals),
    kwargs...,
)::Union{Failure,RecursiveSolution}

    constraints = copy(parent_constrations)
    @label START_PLANNING
    # check time limit
    is_expired(deadline) && return FAILURE_TIMEOUT

    # compute collision-free paths
    paths = multi_agent_path_planner(
        ins.G,
        starts,
        ins.goals,
        crashes,
        constraints,
        offset;
        deadline = deadline,
        h_func = h_func,
        VERBOSE = VERBOSE - 1,
        kwargs...,
    )
    if isnothing(paths)
        if is_expired(deadline)
            verbose(VERBOSE, 1, deadline, "reaching time limit")
            return FAILURE_TIMEOUT
        elseif isempty(crashes)
            verbose(VERBOSE, 1, deadline, "failed to find initial solution")
            return FAILURE_NO_INITIAL_SOLUTION
        else
            verbose(VERBOSE, 1, deadline, "failed to find backup paths")
            return FAILURE_NO_BACKUP_PATH
        end
    end

    # identify critical sections
    U = is_no_more_crash(ins, crashes) ? [] : get_new_unresolved_events(paths, offset)
    # compute backup paths
    backup = Dict()
    for event in U
        # recursive call
        res = planner2(
            ins,
            map(path -> get_in_range(path, event.crash.when - offset + 1), paths),
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
        if isa(res, Failure)
            verbose(VERBOSE, 2, deadline, "add constraints $(event.effect)")
            # update constrains
            push!(constraints, event.effect)
            # re-planning
            @goto START_PLANNING
        end
        backup[event.crash] = res
    end
    return RecursiveSolution(paths = paths, offset = offset, backup = backup)
end

function flatten_recursive_solution(
    recursive_solution::Union{Failure,RecursiveSolution},
)::Union{Failure,Solution}
    isa(recursive_solution, Failure) && return recursive_solution

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
            @assert(t_i != t_j, "collision occurs")
            if t_i < t_j
                c_i = SyncCrash(who = i, loc = v, when = t_i + offset - 1)
                e_j = SyncEffect(who = j, when = t_j + offset - 1, loc = v, plan_id = 1)
                push!(U, Event(crash = c_i, effect = e_j))
            elseif t_j < t_i
                c_j = SyncCrash(who = j, loc = v, when = t_j + offset - 1)
                e_i = SyncEffect(who = i, when = t_i + offset - 1, loc = v, plan_id = 1)
                push!(U, Event(crash = c_j, effect = e_i))
            end
        end
        push!(table[v], (i, t_i))
    end
    return U
end
