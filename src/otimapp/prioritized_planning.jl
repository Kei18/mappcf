"""
prioritized planning
"""

function seq_prioritized_planning(
    G::Graph,
    starts::Config,
    goals::Config;
    h_func = gen_h_func(G, goals),
    VERBOSE::Int = 0,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    do_refinement::Bool = false,
    avoid_duplicates_weight::Real = 0.01,
    specified_planning_order::Vector{Int} = collect(1:length(starts)),
    shuffle_planning_order::Bool = false,
    avoid_starts::Bool = false,
    seed::Int = 0,
)::Union{Nothing,Paths}
    seed!(seed)

    N = length(starts)
    K = length(G)
    paths = map(i -> Path(), 1:N)
    planning_order = copy(specified_planning_order)

    # fragments table
    table = FragmentTable()

    # for h-value
    used_cnt_table = fill(0, K)
    get_duplicated_score() = sum(map(k -> k <= 1 ? 0 : k - 1, used_cnt_table))

    iter = 0
    while true
        iter += 1

        current_score = iter == 1 ? typemax(Int) : get_duplicated_score()
        verbose(
            VERBOSE,
            1,
            deadline,
            "iteration-$(iter) starts\tcurrent_score: $current_score",
        )
        shuffle_planning_order && iter > 1 && (planning_order = randperm(N))

        # main
        for (k, i) in enumerate(planning_order)
            # update deadlock table & used_cnt_table
            cnt_duplicates = typemax(Int)
            if !isempty(paths[i])
                cnt_duplicates = 0
                nothing
            end

            invalid =
                (S_from, S_to) -> begin
                    # avoid other starts
                    avoid_starts && S_to.v != starts[i] && S_to.v in starts && return true
                    # potential terminal deadlock
                    (S_to.v != goals[i] && S_to.v in goals) && return true
                    # potential cyclic deadlock
                    potential_deadlock_exists(S_from.v, S_to.v, table) && return true
                    return false
                end

            h_func_i = (v) -> h_func(i)(v) + used_cnt_table[v] * avoid_duplicates_weight

            # A* search
            path = basic_pathfinding(
                G = G,
                start = starts[i],
                goal = goals[i],
                invalid = invalid,
                h_func = h_func_i,
                deadline = deadline,
            )

            # failure case
            if isnothing(path)
                VERBOSE == 2 && print("\n")
                verbose(VERBOSE, 1, deadline, "agent-$(i) fails to find a path")
                return nothing
            end

            updated_cnt_duplicates = count(map(v -> used_cnt_table[v] > 0, path))
            # register
            if updated_cnt_duplicates < cnt_duplicates
                if !isempty(paths[i])
                    foreach(v -> used_cnt_table[v] -= 1, paths[i])
                    remove_fragments!(table, i)
                end
                paths[i] = path
                fast_register!(table, i, path; deadline = deadline)
                foreach(v -> used_cnt_table[v] += 1, path)
            end
        end

        VERBOSE == 2 && println()
        !do_refinement && break
        get_duplicated_score() >= current_score && break
    end

    return paths
end

function SeqPP(args...; kwargs...)::Union{Nothing,Paths}
    return seq_prioritized_planning(args...; kwargs...)
end

# revisited prioritized planning
function SeqRPP(args...; kwargs...)::Union{Nothing,Paths}
    return seq_prioritized_planning(args...; avoid_starts = true, kwargs...)
end

# revisited prioritized planning with refinement
function SeqRPP_refine(args...; kwargs...)::Union{Nothing,Paths}
    return seq_prioritized_planning(
        args...;
        avoid_starts = true,
        do_refinement = true,
        kwargs...,
    )
end

# PP with random planning order
function SeqPP_repeat(
    args...;
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    VERBOSE::Int = 0,
    kwargs...,
)::Union{Nothing,Paths}
    N = length(args[2])
    iter_cnt = 0
    while !is_expired(deadline)
        iter_cnt += 1
        paths = seq_prioritized_planning(
            args...;
            specified_planning_order = randperm(N),
            deadline = deadline,
            VERBOSE = VERBOSE - 1,
            kwargs...,
        )
        !isnothing(paths) && return paths
    end
    return nothing
end

# RPP with random planning order
function SeqRPP_repeat_refine(args...; kwargs...)
    return SeqPP_repeat(args...; avoid_starts = true, do_refinement = true, kwargs...)
end
