abstract type Instance end

# synchronous model
@kwdef struct SyncInstance <: Instance
    G::Graph
    starts::Config
    goals::Config
    max_num_crashes::Union{Nothing,Int} = nothing
end

SyncInstance(
    G::Graph,
    starts::Config,
    goals::Config,
    max_num_crashes::Union{Nothing,Int} = nothing,
) = begin
    SyncInstance(G = G, starts = starts, goals = goals, max_num_crashes = max_num_crashes)
end

# sequential model
@kwdef struct SeqInstance <: Instance
    G::Graph
    starts::Config
    goals::Config
    max_num_crashes::Union{Nothing,Int} = nothing
end

SeqInstance(
    G::Graph,
    starts::Config,
    goals::Config,
    max_num_crashes::Union{Nothing,Int} = nothing,
) = begin
    SeqInstance(G = G, starts = starts, goals = goals, max_num_crashes = max_num_crashes)
end

function generate_random_instance_grid(;
    N_min::Int = 5,
    N_max::Int = 10,
    N::Int = rand(N_min:N_max),
    filename::Union{Nothing,String} = nothing,
    width::Int = 8,
    height::Int = 8,
    occupancy_rate::Real = 0.1,
)::Tuple{Graph,Config,Config}  # graph, starts, goals

    G =
        isnothing(filename) ?
        generate_random_grid(width, height; occupancy_rate = occupancy_rate) :
        load_mapf_bench(filename)
    vertex_ids = filter(k -> !isempty(get_neighbors(G, k)), 1:length(G))
    @assert(N < 2 * length(vertex_ids), "too many agents on a graph")
    random_indexes = randperm(length(vertex_ids))
    starts = vertex_ids[random_indexes[1:N]]
    goals = vertex_ids[random_indexes[N+1:2N]]
    return (G, starts, goals)
end

function generate_random_sync_instance_grid(; kwargs...)::SyncInstance
    return SyncInstance(generate_random_instance_grid(; kwargs...)...)
end

function generate_random_seq_instance_grid(; kwargs...)::SeqInstance
    return SeqInstance(generate_random_instance_grid(; kwargs...)...)
end

function generate_multiple_random_sync_instance_grid(;
    num::Int,
    kwargs...,
)::Vector{SyncInstance}
    return map(i -> generate_random_sync_instance_grid(; kwargs...), 1:num)
end

function generate_multiple_random_seq_instance_grid(;
    num::Int,
    kwargs...,
)::Vector{SeqInstance}
    return map(i -> generate_random_seq_instance_grid(; kwargs...), 1:num)
end


function generate_random_instance_grid_wellformed(;
    N_min::Int = 5,
    N_max::Int = 10,
    N::Int = rand(N_min:N_max),
    filename::Union{Nothing,String} = nothing,
    width::Int = 8,
    height::Int = 8,
    occupancy_rate::Real = 0.1,
)::Tuple{Graph,Config,Config}  # graph, starts, goals

    G =
        isnothing(filename) ?
        generate_random_grid(width, height; occupancy_rate = occupancy_rate) :
        load_mapf_bench(filename)
    vertex_ids = filter(k -> !isempty(get_neighbors(G, k)), 1:length(G))
    K = length(vertex_ids)
    @assert(N < 2 * K, "too many agents on a graph")
    starts, goals = [], []

    # produce well-formed start-goal pair
    while length(goals) != N
        random_indexes = randperm(K)
        starts = vertex_ids[random_indexes[1:N]]
        goals = []
        prohibited = []
        k = N
        for i = 1:N
            s = starts[i]
            while k < K
                k += 1
                g = vertex_ids[random_indexes[k]]
                g in prohibited && continue
                path = basic_pathfinding(
                    G = G,
                    start = s,
                    goal = g,
                    invalid = (S_from, S_to) -> begin
                        S_to.v != g && S_to.v in goals && return true
                        S_to.v != s && S_to.v in starts && return true
                        return false
                    end,
                )
                if !isnothing(path)
                    prohibited = vcat(prohibited, path)
                    push!(goals, g)
                    break
                end
            end
            length(goals) != i && break
        end
    end
    return (G, starts, goals)
end

function generate_random_sync_instance_grid_wellformed(; kwargs...)::SyncInstance
    return SyncInstance(generate_random_instance_grid_wellformed(; kwargs...)...)
end

function generate_random_seq_instance_grid_wellformed(; kwargs...)::SeqInstance
    return SeqInstance(generate_random_instance_grid_wellformed(; kwargs...)...)
end

function generate_multiple_random_sync_instance_grid_wellformed(;
    num::Int,
    kwargs...,
)::Vector{SyncInstance}
    return map(i -> generate_random_sync_instance_grid_wellformed(; kwargs...), 1:num)
end

function generate_multiple_random_seq_instance_grid_wellformed(;
    num::Int,
    kwargs...,
)::Vector{SeqInstance}
    return map(i -> generate_random_seq_instance_grid_wellformed(; kwargs...), 1:num)
end
