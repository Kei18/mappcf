@kwdef struct Constraint
    agent::Int64
    v::Int
end

@kwdef struct HighLevelNode
    paths::Union{Nothing,Paths} = nothing
    constraints::Vector{Constraint} = Vector{Constraint}()
    f::Float64 = 0.0
end
Base.lt(o::FastForwardOrdering, a::HighLevelNode, b::HighLevelNode) = a.f < b.f

# benchmark
function CBS(
    ins::Instance,
    ;
    VERBOSE::Int = 0,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    h_func::Function = gen_h_func(ins),
    avoid_duplicates_weight::Real = 10,
)::Union{Failure,Solution}

    N = length(ins.starts)
    OPEN = FastBinaryHeap{HighLevelNode}()
    S_init = get_initial_search_node(
        ins;
        deadline = deadline,
        h_func = h_func,
        avoid_duplicates_weight = avoid_duplicates_weight,
    )
    isnothing(S_init) && return (
        is_expired(deadline) ? FAILURE_TIMEOUT_INITIAL_SOLUTION :
        FAILURE_NO_INITIAL_SOLUTION
    )
    push!(OPEN, S_init)

    loop_cnt = 0
    while !isempty(OPEN)
        is_expired(deadline) && return FAILURE_TIMEOUT_INITIAL_SOLUTION
        loop_cnt += 1

        # pop
        S = pop!(OPEN)
        verbose(
            VERBOSE,
            2,
            deadline,
            "iter:$(loop_cnt)\tS.f:$(S.f)";
            CR = true,
            LF = VERBOSE > 2,
        )

        # get constraints
        constraints = get_constraints(S)
        if isempty(constraints)
            VERBOSE > 1 && println()
            verbose(VERBOSE, 1, deadline, "found solution")
            return map(i -> [Plan(id = 1, who = i, path = S.paths[i], offset = 1)], 1:N)
        end
        # create new nodes
        for c in constraints
            S_new = get_new_node(
                ins,
                S,
                c;
                deadline = deadline,
                h_func = h_func,
                avoid_duplicates_weight = avoid_duplicates_weight,
            )
            !isnothing(S_new) && push!(OPEN, S_new)
        end
    end

    return FAILURE_NO_INITIAL_SOLUTION
end

function get_new_node(
    ins::Instance,
    S::HighLevelNode,
    new_constraint::Constraint;
    deadline::Union{Nothing,Deadline} = nothing,
    h_func::Function = (i::Int) -> ((v) -> 0),
    avoid_duplicates_weight::Real = 10,
)::Union{Nothing,HighLevelNode}

    i = new_constraint.agent
    N = length(S.paths)

    occupied = fill(false, length(ins.G))
    foreach(v -> occupied[v] = true, ins.starts)
    foreach(v -> occupied[v] = true, ins.goals)
    used_cnt = fill(0, length(ins.G))
    for j = 1:N
        j == i && continue
        foreach(v -> used_cnt[v] += 1, S.paths[j])
    end
    h_func_i = (v) -> h_func(i)(v) + used_cnt[v] * avoid_duplicates_weight

    constraints = vcat(S.constraints, new_constraint)
    constraints_i = filter(c -> c.agent == i, constraints)

    invalid =
        (S_from, S_to) -> begin
            S_to.v != ins.goals[i] && occupied[S_to.v] && return true
            any(c -> S_to.v == c.v, constraints_i) && return true
            return false
        end

    path = basic_pathfinding(
        G = ins.G,
        start = ins.starts[i],
        goal = ins.goals[i],
        invalid = invalid,
        deadline = deadline,
        h_func = h_func_i,
    )
    isnothing(path) && return nothing

    paths = copy(S.paths)
    paths[i] = path
    foreach(v -> used_cnt[v] += 1, path)

    return HighLevelNode(
        paths = paths,
        constraints = constraints,
        f = sum(k -> max(0, k - 1), used_cnt),
    )
end

function get_initial_search_node(
    ins::Instance;
    deadline::Union{Nothing,Deadline},
    h_func::Function,
    avoid_duplicates_weight::Real = 10,
)::Union{HighLevelNode,Nothing}

    N = length(ins.starts)

    # step 1, initial paths
    paths = Paths()
    occupied = fill(false, length(ins.G))
    foreach(v -> occupied[v] = true, ins.starts)
    foreach(v -> occupied[v] = true, ins.goals)
    used_cnt = fill(0, length(ins.G))
    for i = 1:N
        h_func_i = (v) -> h_func(i)(v) + used_cnt[v] * avoid_duplicates_weight
        path = basic_pathfinding(
            G = ins.G,
            start = ins.starts[i],
            goal = ins.goals[i],
            invalid = (S_from, S_to) -> (S_to.v != ins.goals[i] && occupied[S_to.v]),
            deadline = deadline,
            h_func = h_func_i,
        )
        isnothing(path) && return nothing
        push!(paths, path)
        foreach(v -> used_cnt[v] += 1, path)
    end

    return HighLevelNode(
        paths = paths,
        constraints = [],
        f = sum(k -> max(0, k - 1), used_cnt),
    )
end

function get_constraints(S::HighLevelNode)::Vector{Constraint}
    N = length(S.paths)
    constraints = Vector{Constraint}()
    for i = 1:N, v_i in S.paths[i]
        for j = i+1:N, v_j in S.paths[j]
            if v_j == v_i
                push!(constraints, Constraint(agent = i, v = v_i))
                push!(constraints, Constraint(agent = j, v = v_j))
                return constraints
            end
        end
    end
    return constraints
end
