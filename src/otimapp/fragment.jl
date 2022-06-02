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
