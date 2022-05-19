@kwdef struct AstarNode
    v::Int
    g::Int = 0
    h::Int = 0
    f::Int = g + h
    p::Union{Nothing,AstarNode} = nothing
end

# seq model
function seq_prioritized_planning(
    G::Graph,
    starts::Config,
    goals::Config;
    dist_tables::Vector{Vector{Int}} = map(g -> get_distance_table(G, g), goals),
    VERBOSE::Int = 0,
)

    N = length(starts)
    paths = map(i -> Path(), 1:N)

    # fragments table
    T_f = Dict{Int,Vector}()  # from
    T_t = Dict{Int,Vector}()  # to
    register! = (t) -> begin
        get!(T_f, first(t.path), [])
        get!(T_t, last(t.path), [])
        push!(T_f[first(t.path)], t)
        push!(T_t[last(t.path)], t)
    end

    for i = 1:N

        # heuristics
        h_func = (v) -> dist_tables[i][v]

        # setup search
        OPEN = PriorityQueue{AstarNode,Float64}()
        CLOSE = fill(false, length(G))
        S = AstarNode(v = starts[i], g = 0, h = h_func(starts[i]))
        enqueue!(OPEN, S, S.f)

        while !isempty(OPEN)
            # pop
            S = dequeue!(OPEN)
            CLOSE[S.v] && continue
            CLOSE[S.v] = true

            # check goal condition
            if S.v == goals[i]
                # backtracking
                path = []
                while !isnothing(S.p)
                    pushfirst!(path, S.v)
                    S = S.p
                end
                pushfirst!(path, starts[i])
                paths[i] = path
                break
            end

            # expand
            for u in get_neighbors(G, S.v)
                # check closed list
                CLOSE[u] && continue

                # check invalid: TODO
                (u != goals[i] && u in goals) && continue
                haskey(T_t, S.v) && any(t -> first(t.path) == u, T_t[S.v]) && continue

                # add new search node
                S_new = AstarNode(v = u, g = S.v + 1, h = h_func(u), p = S)
                !haskey(OPEN, S_new) && enqueue!(OPEN, S_new, S_new.f)
            end
        end

        # failure
        if isempty(paths[i])
            VERBOSE > 0 && @info(@sprintf("failed to find a path for agent-%d", i))
            return nothing
        end

        # register fragments
        for k = 1:length(paths[i])-1
            u = paths[i][k]
            v = paths[i][k+1]

            # register
            fragment = (agents = [i], path = [u, v])
            register!(fragment)

            for t in get!(T_t, u, [])
                i in t.agents && continue
                register!((agents = vcat(t.agents, i), path = vcat(t.path, v)))
            end

            for t in get!(T_f, v, [])
                i in t.agents && continue
                register!((agents = vcat(i, t.agents), path = vcat(u, t.path)))
            end

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

    return paths
end
