"""
utility functions
"""

function setup_runtime_profile!(runtime_profile::Dict{Symbol,Real})
    runtime_profile[:elapsed_find_backup_plan] = 0
    runtime_profile[:elapsed_identify_new_event] = 0
    runtime_profile[:elapsed_initial_paths] = 0
    runtime_profile[:elapsed_initial_setup] = 0
end

# algorithms to obtain initial paths

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

function RPP_refine(ins::SyncInstance; kwargs...)::Union{Nothing,Paths}
    return MAPF.RPP_refine(ins.G, ins.starts, ins.goals; kwargs...)
end

function SeqRPP_refine(ins::SeqInstance; kwargs...)::Union{Nothing,Paths}
    return OTIMAPP.SeqRPP_refine(ins.G, ins.starts, ins.goals; kwargs...)
end

function SeqRPP_repeat_refine(ins::SeqInstance; kwargs...)::Union{Nothing,Paths}
    return OTIMAPP.SeqRPP_repeat_refine(ins.G, ins.starts, ins.goals; kwargs...)
end
