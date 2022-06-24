abstract type Instance end

# synchronous model
@kwdef struct SyncInstance <: Instance
    G::Graph
    starts::Config
    goals::Config
    max_num_crashes::Union{Nothing,Int} = length(starts) - 1
end

# sequential model
@kwdef struct SeqInstance <: Instance
    G::Graph
    starts::Config
    goals::Config
    max_num_crashes::Union{Nothing,Int} = length(starts) - 1
end

Base.show(io::IO, ins::SyncInstance) = print(
    io,
    "SyncInstance(starts=$(ins.starts), goals=$(ins.goals), max_num_crashes=$(ins.max_num_crashes))",
)
Base.show(io::IO, ins::SeqInstance) = print(
    io,
    "SeqInstance(starts=$(ins.starts), goals=$(ins.goals), max_num_crashes=$(ins.max_num_crashes))",
)


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

function generate_random_sync_instance_grid(;
    max_num_crashes::Union{Nothing,Int} = nothing,
    kwargs...,
)::SyncInstance
    return SyncInstance(generate_random_instance_grid(; kwargs...)..., max_num_crashes)
end

function generate_random_seq_instance_grid(;
    max_num_crashes::Union{Nothing,Int} = nothing,
    kwargs...,
)::SeqInstance
    return SeqInstance(generate_random_instance_grid(; kwargs...)..., max_num_crashes)
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
                dist_table = get_distance_table(G, g)
                h_func_i = (v) -> dist_table[v]

                path = basic_pathfinding(
                    G = G,
                    start = s,
                    goal = g,
                    invalid = (S_from, S_to) -> begin
                        S_to.v != g && S_to.v in goals && return true
                        S_to.v != s && S_to.v in starts && return true
                        return false
                    end,
                    h_func = h_func_i,
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

function get_max_num_crashes(
    max_num_crashes_min::Union{Nothing,Int},
    max_num_crashes_max::Union{Nothing,Int},
)::Union{Nothing,Int}
    isnothing(max_num_crashes_min) && isnothing(max_num_crashes_max) && return nothing
    a = isnothing(max_num_crashes_min) ? 0 : max_num_crashes_min
    b = isnothing(max_num_crashes_max) ? a : max_num_crashes_max
    return rand(a:b)
end

function generate_random_sync_instance_grid_wellformed(;
    max_num_crashes_min::Union{Nothing,Int} = nothing,
    max_num_crashes_max::Union{Nothing,Int} = nothing,
    max_num_crashes::Union{Nothing,Int} = get_max_num_crashes(
        max_num_crashes_min,
        max_num_crashes_max,
    ),
    kwargs...,
)::SyncInstance
    ins = generate_random_instance_grid_wellformed(; kwargs...)
    return SyncInstance(
        ins...,
        isnothing(max_num_crashes) ? nothing : min(max_num_crashes, length(last(ins)) - 1),
    )
end

function generate_random_seq_instance_grid_wellformed(;
    max_num_crashes_min::Union{Nothing,Int} = nothing,
    max_num_crashes_max::Union{Nothing,Int} = nothing,
    max_num_crashes::Union{Nothing,Int} = get_max_num_crashes(
        max_num_crashes_min,
        max_num_crashes_max,
    ),
    kwargs...,
)::SeqInstance
    ins = generate_random_instance_grid_wellformed(; kwargs...)
    return SeqInstance(
        ins...,
        isnothing(max_num_crashes) ? nothing : min(max_num_crashes, length(last(ins)) - 1),
    )
end

function generate_multiple_instances(
    fn::Function;
    num::Int,
    VERBOSE::Int = 0,
    kwargs...,
)::Vector{Instance}
    instances = Vector{Instance}(undef, num)
    cnt_fin = Threads.Atomic{Int}(0)
    Threads.@threads for k = 1:num
        instances[k] = fn(; kwargs...)
        Threads.atomic_add!(cnt_fin, 1)
        VERBOSE > 0 && print("\r$(cnt_fin[])/$num instances are generated")
    end
    VERBOSE > 0 && print("\n")
    return instances
end

function generate_multiple_random_sync_instance_grid_wellformed(;
    kwargs...,
)::Vector{SyncInstance}
    return generate_multiple_instances(
        generate_random_sync_instance_grid_wellformed;
        kwargs...,
    )
end

function generate_multiple_random_seq_instance_grid_wellformed(;
    kwargs...,
)::Vector{SeqInstance}
    return generate_multiple_instances(
        generate_random_seq_instance_grid_wellformed;
        kwargs...,
    )
end
