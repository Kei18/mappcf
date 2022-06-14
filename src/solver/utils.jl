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

function can_add_crash(ins::Instance, crashes::Vector{Crash})::Bool
    return isnothing(ins.max_num_crashes) || length(crashes) + 1 <= ins.max_num_crashes
end

function astar_operator_decomposition(ins::SyncInstance; kwargs...)::Union{Nothing,Paths}
    return MAPF.astar_operator_decomposition(ins.G, ins.starts, ins.goals; kwargs...)
end

function PP(ins::SyncInstance; kwargs...)::Union{Nothing,Paths}
    return MAPF.prioritized_planning(ins.G, ins.starts, ins.goals; kwargs...)
end

function RPP(ins::SyncInstance; kwargs...)::Union{Nothing,Paths}
    return MAPF.RPP(ins.G, ins.starts, ins.goals; kwargs...)
end

function gen_RPP(; kwargs1...)::Function
    return (ins; kwargs2...) ->
        MAPF.RPP(ins.G, ins.starts, ins.goals; kwargs1..., kwargs2...)
end

function SeqRPP(ins::SeqInstance; kwargs...)::Union{Nothing,Paths}
    return OTIMAPP.SeqRPP(ins.G, ins.starts, ins.goals; kwargs...)
end
