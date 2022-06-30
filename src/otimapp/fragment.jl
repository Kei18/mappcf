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

function register!(
    table::FragmentTable,
    i::Int,
    path::Path;
    deadline::Union{Nothing,Deadline} = nothing,
)::Nothing
    for k = 1:length(path)-1
        is_expired(deadline) && break
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

function get_sorted_agents(i::Int, t::Fragment)::Union{Nothing,Vector{Int}}
    agents = Array{Int}(undef, length(t.agents) + 1)
    invalid = false
    inserted = false
    k = 1
    for j in t.agents
        if j == i
            invalid = true
            break
        elseif j < i
            agents[k] = j
            k += 1
        elseif !inserted
            agents[k] = i
            agents[k+1] = j
            k += 2
            inserted = true
        else
            agents[k] = j
            k += 1
        end
    end
    !inserted && (agents[end] = i)
    return !invalid ? agents : nothing
end

function get_sorted_agents(i::Int, t_t::Fragment, t_f::Fragment)::Union{Nothing,Vector{Int}}
    A = t_t.agents
    B = t_f.agents
    k = 0
    k_i = 1
    k_t = 1
    k_f = 1
    invalid = false

    agents = Array{Int}(undef, length(A) + length(B) + 1)
    for k = 1:length(agents)
        if k_t > length(A)
            if k_f > length(B)
                agents[k] = i
                k_i += 1
            elseif k_i > 1
                agents[k] = B[k_f]
                k_f += 1
            elseif B[k_f] < i
                agents[k] = B[k_f]
                k_f += 1
            elseif B[k_f] > i
                agents[k] = i
                k_i += 1
            else  # B[k_f] = i
                invalid = true
                break
            end
        elseif k_f > length(B)
            if k_t > length(A)
                agents[k] = i
                k_i += 1
            elseif k_i > 1
                agents[k] = A[k_t]
                k_t += 1
            elseif A[k_t] < i
                agents[k] = A[k_t]
                k_t += 1
            elseif A[k_t] > i
                agents[k] = i
                k_i += 1
            else  # A[k_t] = i
                invalid = true
                break
            end
        elseif k_i > 1
            if k_t > length(A)
                agents[k] = B[k_f]
                k_f += 1
            elseif k_f > length(B)
                agents[k] = A[k_t]
                k_t += 1
            elseif A[k_t] < B[k_f]
                agents[k] = A[k_t]
                k_t += 1
            elseif A[k_t] > B[k_f]
                agents[k] = B[k_f]
                k_f += 1
            else  # A[k_t] = B[k_f]
                invalid = true
                break
            end
        else
            if i < A[k_t] && i < B[k_f]
                agents[k] = i
                k_i += 1
            elseif A[k_t] < i && A[k_t] < B[k_f]
                agents[k] = A[k_t]
                k_t += 1
            elseif B[k_f] < i && B[k_f] < A[k_t]
                agents[k] = B[k_f]
                k_f += 1
            else
                invalid = true
                break
            end
        end
    end
    return !invalid ? agents : nothing
end

function fast_register!(
    table::FragmentTable,
    i::Int,
    path::Path;
    deadline::Union{Nothing,Deadline} = nothing,
)::Nothing
    for k = 1:length(path)-1
        is_expired(deadline) && break
        u = path[k]    # from
        v = path[k+1]  # to

        # a fragment only with i
        register!(table, Fragment(agents = [i], path = [u, v]))

        # (known fragment)->u->v
        T_t = Vector{Fragment}()
        for t in get(table.to, u, [])
            agents = get_sorted_agents(i, t)
            if !isnothing(agents)
                register!(table, Fragment(agents = agents, path = vcat(t.path, v)))
                push!(T_t, t)
            end
        end

        # u->v->(known fragment)
        T_f = Vector{Fragment}()
        for t in get(table.from, v, [])
            agents = get_sorted_agents(i, t)
            if !isnothing(agents)
                register!(table, Fragment(agents = agents, path = vcat(u, t.path)))
                push!(T_f, t)
            end
        end

        # (known fragment 1)->u->v->(known fragment 2)
        for t_t in T_t
            for t_f in T_f
                agents = get_sorted_agents(i, t_t, t_f)
                !isnothing(agents) && register!(
                    table,
                    Fragment(agents = agents, path = vcat(t_t.path, t_f.path)),
                )
            end
        end
    end
end

function potential_deadlock_exists(v_from::Int, v_to::Int, table::FragmentTable)::Bool
    return haskey(table.to, v_from) && any(f -> first(f.path) == v_to, table.to[v_from])
end
