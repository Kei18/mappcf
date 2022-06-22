@kwdef mutable struct EventQueue
    body::PriorityQueue{Event,Real} = PriorityQueue{Event,Real}()
    f::Function = (e::Event, U::EventQueue) -> length(U) + 1
    agents_counts::Dict{Int,Int} = Dict()
end

function enqueue!(U::EventQueue, e::Event)
    if !haskey(U.body, e)
        enqueue!(U.body, e, U.f(e, U))

        # for heuristics
        i = e.effect.who
        get!(U.agents_counts, i, 0)
        U.agents_counts[i] += 1
    end
end

function dequeue!(U::EventQueue)::Union{Nothing,Event}
    return dequeue!(U.body)
end

function length(U::EventQueue)::Int
    return length(U.body)
end

function isempty(U::EventQueue)::Bool
    return isempty(U.body)
end
