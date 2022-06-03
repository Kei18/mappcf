function prioritized_planning(
    G::Graph,
    starts::Config,
    goals::Config;
    dist_tables::Vector{Vector{Int}} = map(g -> get_distance_table(G, g), goals),
    VERBOSE::Int = 0,
    time_limit_sec::Union{Nothing,Real} = nothing,
    deadline::Union{Nothing,Deadline} = isnothing(time_limit_sec) ? nothing :
                                        generate_deadline(time_limit_sec),
    kwargs...,
)::Union{Nothing,Paths}
    N = length(starts)
    paths = map(i -> Path(), 1:N)

    # fragments table
    table = FragmentTable()

    for i = 1:N

        h_func = (v) -> dist_tables[i][v]

        invalid =
            (S_from, S_to) -> begin
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
            h_func = h_func,
            deadline = deadline,
        )

        # failure
        isnothing(path) && return nothing

        # register
        paths[i] = path
        i < N && register!(table, i, path)
    end

    return paths
end
