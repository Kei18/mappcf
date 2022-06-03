function get_sync_event(;
    v::Int,
    i::Int,
    j::Int,
    t_i::Int,
    t_j::Int,
    plan_i_id::Int = 1,
    plan_j_id::Int = 1,
    offset::Int = 1,
)::Event

    @assert(i != j, "add_event!")
    @assert(t_i != t_j, "collision occurs")

    if t_i < t_j
        c_i = SyncCrash(who = i, loc = v, when = t_i + offset - 1)
        e_j = SyncEffect(who = j, when = t_j + offset - 1, loc = v, plan_id = plan_j_id)
        return Event(crash = c_i, effect = e_j)
    else  # t_j < t_i
        c_j = SyncCrash(who = j, loc = v, when = t_j + offset - 1)
        e_i = SyncEffect(who = i, when = t_i + offset - 1, loc = v, plan_id = plan_i_id)
        return Event(crash = c_j, effect = e_i)
    end
end

function add_event!(
    U::Vector{Event},
    ins::SeqInstance;
    v::Int,
    plan_i::Plan,
    plan_j::Plan,
    t_j::Int,
    t_i::Int,
)::Nothing

    i = plan_i.who
    j = plan_j.who
    @assert(i != j, "add_event!")
    c_i = SeqCrash(who = i, loc = v)
    c_j = SeqCrash(who = j, loc = v)
    if t_i > 1 && !haskey(plan_i.backup, c_j)
        e_i = SeqEffect(who = i, when = t_i, loc = v, plan_id = plan_i.id)
        push!(U, Event(crash = c_j, effect = e_i))
    end
    if t_j > 1 && !haskey(plan_j.backup, c_i)
        e_j = SeqEffect(who = j, when = t_j, loc = v, plan_id = plan_j.id)
        push!(U, Event(crash = c_i, effect = e_j))
    end
    nothing
end

function add_event!(
    U::Vector{Event},
    ins::SyncInstance;
    v::Int,
    plan_i::Plan,
    plan_j::Plan,
    t_i::Int,
    t_j::Int,
)::Nothing
    push!(
        U,
        get_sync_event(
            v = v,
            i = plan_i.who,
            j = plan_j.who,
            t_i = t_i,
            t_j = t_j,
            plan_i_id = plan_i.id,
            plan_j_id = plan_j.id,
        ),
    )
    nothing
end

function astar_operator_decomposition(ins::SyncInstance; kwargs...)::Union{Nothing,Paths}
    return astar_operator_decomposition(ins.G, ins.starts, ins.goals; kwargs...)
end

function seq_prioritized_planning(ins::SeqInstance; kwargs...)::Union{Nothing,Paths}
    return seq_prioritized_planning(ins.G, ins.starts, ins.goals; kwargs...)
end
