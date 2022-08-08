"""
instance generation example, used in tests
"""

using MAPPFD

function generate_sample_graph1()::Graph
    G = map(i -> Vertex(id = i), 1:5)
    G[1].pos = [0, 0]
    G[2].pos = [1, 0]
    G[3].pos = [2, 0]
    G[4].pos = [0.5, 1]
    G[5].pos = [0.5, -1]
    add_edges!(G, (1, 2), (2, 3), (1, 4), (2, 4), (1, 5), (2, 5))
    return G
end

function generate_sample_graph2()::Graph
    G = generate_grid(5, 5; obstacle_locs = [21, 23, 25, 18, 20, 8])
    remove_edges!(G, (2, 7), (4, 9), (9, 10))
    return G
end

function generate_sample_graph3()::Graph
    G = generate_grid(5, 2, obstacle_locs = [1, 4, 5])
    remove_edges!(G, (2, 7), (3, 8), (2, 3))
    add_edges!(G, (2, 8), (3, 9), (3, 8))
    return G
end

function generate_sample_graph4()::Graph
    G = generate_grid(3, 3, obstacle_locs = [1, 3, 7, 9])
    add_edges!(G, (2, 4), (2, 6), (8, 6))
    return G
end

function generate_sample_sync_instance1(
    max_num_crashes::Union{Nothing,Int} = nothing,
)::SyncInstance
    return SyncInstance(generate_sample_graph1(), [1, 4], [3, 5], max_num_crashes)
end

function generate_sample_sync_instance2(
    max_num_crashes::Union{Nothing,Int} = nothing,
)::SyncInstance
    return SyncInstance(generate_sample_graph2(), [11, 22, 24], [15, 7, 9], max_num_crashes)
end

function generate_sample_sync_instance4(
    max_num_crashes::Union{Nothing,Int} = nothing,
)::SyncInstance
    return SyncInstance(generate_sample_graph4(), [4, 8], [6, 2], max_num_crashes)
end

function generate_sample_seq_instance4(
    max_num_crashes::Union{Nothing,Int} = nothing,
)::SeqInstance
    return SeqInstance(generate_sample_graph4(), [4, 8], [6, 2], max_num_crashes)
end
