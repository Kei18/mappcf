module MAPPFD

import Random: seed!
import Printf: @printf, @sprintf
import Base: @kwdef
import DataStructures: PriorityQueue, enqueue!, dequeue!
using Plots

include("graph.jl")

# type definitions
Config = Vector{Int}  # vertex indexes


@kwdef struct Crash
    who::Int   # agent index
    loc::Int   # location index
    when::Int = 0 # timestep
end
Crashes = Vector{Crash}

# History = Vector{Tuple{Config, Crashes}}

function emulate_crashes!(
    config::Config,
    crashes::Crashes;
    timestep::Int = 0,
    failure_prob::Real = 0.2,
    VERBOSE::Int = 0,
)::Nothing
    N = length(config)
    for i in filter(i -> !is_crashed(crashes, i), 1:N)
        if rand() < failure_prob
            loc_id = config[i]
            VERBOSE > 0 && @info(@sprintf("agent-%d is crashed at loc-%d", i, loc_id))
            push!(failures, Crash(who=i, when=timestep, loc=loc_id))
        end
    end
end

function is_neighbor(
    G::Graph,
    config::Config,
    agent::Int,
    target_loc::Int
)::Bool
    return target_loc in get_neighbors(G, config[agent])
end

function is_crashed(crashes::Crashes, agent::Int)::Bool
    return any(crash -> crash.who == agent, crashes)
end

function is_occupied(config::Config, target_loc::Int)::Bool
    return target_loc in config
end

function non_anonymous_failure_detector(
    crashes::Crashes,
    target_loc::Int,
    target_agent::Int
    )::Bool
    return any(crash -> crash.who == target_agent && crash.loc == target_loc, crashes)
end

include("viz.jl")

export Config, Crash, Crashes, is_occupied, is_crashed, non_anonymous_failure_detector

end # module
