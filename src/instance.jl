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
