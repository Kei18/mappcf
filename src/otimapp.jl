module OTIMAPP

import Base: @kwdef
import DataStructures: PriorityQueue, enqueue!, dequeue!
import MAPPFD:
    Graph,
    get_neighbors,
    Path,
    Paths,
    Config,
    get_distance_table,
    get_in_range,
    search,
    SearchNode,
    basic_pathfinding

@kwdef struct Fragment
    agents::Vector{Int} = []
    path::Path = []
end

@kwdef mutable struct FragmentTable
    from::Dict{Int,Vector{Fragment}} = Dict()
    to::Dict{Int,Vector{Fragment}} = Dict()
end

function register!(table::FragmentTable, fragment::Fragment)::Nothing
    v_from = first(fragment.path)
    v_to = last(fragment.path)
    get!(table.from, v_from, [])
    get!(table.to, v_to, [])
    push!(table.from[v_from], fragment)
    push!(table.to[v_to], fragment)
    nothing
end

function register!(table::FragmentTable, i::Int, path::Path)::Nothing
    for k = 1:length(path)-1
        u = path[k]    # from
        v = path[k+1]  # to

        # a fragment only with i
        register!(table, Fragment(agents = [i], path = [u, v]))

        # (known fragment)->u->v
        for t in get(table.to, u, [])
            i in t.agents && continue
            register!(table, Fragment(agents = vcat(t.agents, i), path = vcat(t.path, v)))
        end

        # u->v->(known fragment)
        for t in get(table.from, v, [])
            i in t.agents && continue
            register!(table, Fragment(agents = vcat(i, t.agents), path = vcat(u, t.path)))
        end

        # (known fragment 1)->u->v->(known fragment 2)
        for t_t in get(table.to, u, [])
            i in t_t.agents && continue
            for t_f in get(table.from, v, [])
                i in t_f.agents && continue
                any(l -> l in t_t.agents, t_f.agents) && continue
                register!(
                    table,
                    Fragment(
                        agents = vcat(t_t.agents, i, t_f.agents),
                        path = vcat(t_t.path, t_f.path),
                    ),
                )
            end
        end
    end
end

function potential_deadlock_exists(v_from::Int, v_to::Int, table::FragmentTable)::Bool
    return haskey(table.to, v_from) && any(f -> first(f.path) == v_to, table.to[v_from])
end

function prioritized_planning(
    G::Graph,
    starts::Config,
    goals::Config;
    dist_tables::Vector{Vector{Int}} = map(g -> get_distance_table(G, g), goals),
    VERBOSE::Int = 0,
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
        )

        # failure
        isnothing(path) && return nothing

        # register
        paths[i] = path
        i < N && register!(table, i, path)
    end

    return paths
end

end
