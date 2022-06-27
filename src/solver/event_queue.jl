@kwdef mutable struct EventQueue
    body::FastBinaryHeap{Event} = FastBinaryHeap{Event}()
    f::Function = (c::Crash, e::Effect, U::EventQueue) -> e.when
    agents_counts::Dict{Int,Int} = Dict()
end
Base.lt(o::FastForwardOrdering, a::Event, b::Event) = a.f < b.f

function enqueue!(U::EventQueue, e::Event)
    push!(U.body, e)

    # for heuristics
    i = e.effect.who
    get!(U.agents_counts, i, 0)
    U.agents_counts[i] += 1
end

function dequeue!(U::EventQueue)::Union{Nothing,Event}
    return pop!(U.body)
end

function length(U::EventQueue)::Int
    return length(U.body)
end

function isempty(U::EventQueue)::Bool
    return isempty(U.body)
end
