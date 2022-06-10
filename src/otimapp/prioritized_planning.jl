function seq_prioritized_planning(
    G::Graph,
    starts::Config,
    goals::Config;
    h_func = gen_h_func(G, goals),
    VERBOSE::Int = 0,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    planning_order = collect(1:length(starts)),
    avoid_starts::Bool = false,
)::Union{Nothing,Paths}
    N = length(starts)
    paths = map(i -> Path(), 1:N)

    # fragments table
    table = FragmentTable()

    for (k, i) in enumerate(planning_order)
        VERBOSE > 1 && println(
            "elapsed:$(round(elapsed_sec(deadline), digits=3))sec\tagent-$(i) starts planning",
        )
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

        path = basic_pathfinding(
            G = G,
            start = starts[i],
            goal = goals[i],
            invalid = invalid,
            h_func = h_func(i),
            deadline = deadline,
        )

        # failure
        isnothing(path) && return nothing

        # register
        paths[i] = path
        k < N && register!(table, i, path)
    end

    return paths
end

function SeqPP(args...; kwargs...)::Union{Nothing,Paths}
    return seq_prioritized_planning(args...; kwargs...)
end

function SeqRPP(args...; kwargs...)::Union{Nothing,Paths}
    return seq_prioritized_planning(args...; avoid_starts = true, kwargs...)
end

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
        VERBOSE > 0 && println(
            "elapsed: $(round(elapsed_sec(deadline), digits=3)) s\titer:$(iter_cnt)",
        )
        paths = seq_prioritized_planning(
            args...;
            planning_order = randperm(N),
            deadline = deadline,
            VERBOSE = VERBOSE - 1,
            kwargs...,
        )
        !isnothing(paths) && return paths
    end
    return nothing
end

function SeqRPP_repeat(args...; kwargs...)::Union{Nothing,Paths}
    return SeqPP_repeat(args...; avoid_starts = true, kwargs...)
end
