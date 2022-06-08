abstract type Crash end

# synchronous model
@kwdef struct SyncCrash <: Crash
    who::Int
    loc::Int
    when::Int = 1
end

# sequential model
@kwdef struct SeqCrash <: Crash
    who::Int
    loc::Int
end

Base.show(io::IO, c::SyncCrash) =
    print(io, "SyncCrash(who=$(c.who), loc=$(c.loc), when=$(c.when))")
Base.show(io::IO, c::SeqCrash) = print(io, "SeqCrash(who=$(c.who), loc=$(c.loc))")


function get_correct_crashed_agents(
    N::Int,
    crashes::Vector{T} where {T<:Crash},
)::@NamedTuple {correct_agents::Vector{Int}, crashed_agents::Vector{Int}}
    crashed_agents = map(c -> c.who, crashes)
    correct_agents = filter(i -> all(j -> j != i, crashed_agents), 1:N)
    return (correct_agents = correct_agents, crashed_agents = crashed_agents)
end

function get_correct_crashed_agents(
    N::Int,
    i::Int,
    crashes::Vector{T} where {T<:Crash},
)::@NamedTuple {correct_agents::Vector{Int}, crashed_agents::Vector{Int}}
    (correct_agents, crashed_agents) = get_correct_crashed_agents(N, crashes)
    filter!(j -> j != i, correct_agents)
    return (correct_agents = correct_agents, crashed_agents = crashed_agents)
end

function is_no_more_crash(ins::Instance, crashes::Vector{T} where {T<:Crash})::Bool
    return !isnothing(ins.max_num_crashes) && length(crashes) >= ins.max_num_crashes
end
