abstract type Instance end

# synchronous model
struct SyncInstance <: Instance
    G::Graph
    starts::Config
    goals::Config
end

# sequential model
struct SeqInstance <: Instance
    G::Graph
    starts::Config
    goals::Config
end

function generate_random_instance_grid(;
    N_min::Int = 5,
    N_max::Int = 10,
    N::Int = rand(N_min:N_max),
    width::Int = 8,
    height::Int = 8,
    occupancy_rate::Real = 0.1,
)::Tuple{Graph,Config,Config}  # graph, starts, goals

    G = generate_random_grid(width, height; occupancy_rate = occupancy_rate)
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
