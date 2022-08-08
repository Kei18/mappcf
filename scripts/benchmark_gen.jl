"""
benchmark generation used in experiment
"""

using MAPPFD
import YAML
import Dates
import JLD2
import Glob: glob
import Random: seed!
include("./utils.jl")

function create_benchmarks()
    create_benchmarks_exp1()
    create_benchmarks_exp2()
    create_benchmarks_exp3()
    create_benchmarks_exp4()
end

function create_benchmarks_exp1()
    seed!(1)
    NUM_INS = 25
    MAP_NAME = "random-32-32-10"

    root_dir = joinpath(@__DIR__, "../../data/benchmark/exp1")
    map_filename = joinpath(@__DIR__, "../assets/map/$(MAP_NAME).map")

    # fix number of crashes
    agents = [5, 10, 15, 20, 25, 30]
    loops = collect(enumerate(Iterators.product(agents, 1:NUM_INS)))
    instances = Vector{Instance}(undef, length(loops))
    Threads.@threads for (k, (N,)) in loops
        instances[k] = generate_random_sync_instance_grid_wellformed(;
            N = N,
            max_num_crashes = 1,
            filename = map_filename,
        )
    end
    JLD2.save(joinpath(root_dir, "fix_crash.jld2"), "instances", instances)

    # fix number of agents
    num_crashes = [1, 2, 3, 4, 5]
    loops = collect(1:NUM_INS)
    instances = Vector{Instance}(undef, length(loops) * length(num_crashes))
    Threads.@threads for k in loops
        ins = generate_random_sync_instance_grid_wellformed(;
            N = 15,
            max_num_crashes = 1,
            filename = map_filename,
        )
        for (l, c) in enumerate(num_crashes)
            instances[k+NUM_INS*(l-1)] = typeof(ins)(
                G = ins.G,
                starts = ins.starts,
                goals = ins.goals,
                max_num_crashes = c,
            )
        end
    end
    JLD2.save(joinpath(root_dir, "fix_agent.jld2"), "instances", instances)
end

function create_benchmarks_exp2()
    seed!(1)
    NUM_INS = 25
    MAP_NAME = "random-64-64-10"

    root_dir = joinpath(@__DIR__, "../../data/benchmark/exp2")
    map_filename = joinpath(@__DIR__, "../assets/map/$(MAP_NAME).map")

    # fix number of crashes
    agents = [10, 20, 30, 40, 50, 60]
    loops = collect(enumerate(Iterators.product(agents, 1:NUM_INS)))
    instances = Vector{Instance}(undef, length(loops))
    Threads.@threads for (k, (N,)) in loops
        instances[k] = generate_random_sync_instance_grid_wellformed(;
            N = N,
            max_num_crashes = 1,
            filename = map_filename,
        )
    end
    JLD2.save(joinpath(root_dir, "fix_crash.jld2"), "instances", instances)

    # fix number of agents
    num_crashes = [1, 2, 3, 4, 5]
    loops = collect(1:NUM_INS)
    instances = Vector{Instance}(undef, length(loops) * length(num_crashes))
    Threads.@threads for k in loops
        ins = generate_random_sync_instance_grid_wellformed(;
            N = 15,
            max_num_crashes = 1,
            filename = map_filename,
        )
        for (l, c) in enumerate(num_crashes)
            instances[k+NUM_INS*(l-1)] = typeof(ins)(
                G = ins.G,
                starts = ins.starts,
                goals = ins.goals,
                max_num_crashes = c,
            )
        end
    end
    JLD2.save(joinpath(root_dir, "fix_agent.jld2"), "instances", instances)
end

function create_benchmarks_exp3()
    seed!(1)
    NUM_INS = 25
    MAP_NAME = "Paris_1_256"

    root_dir = joinpath(@__DIR__, "../../data/benchmark/exp3")
    map_filename = joinpath(@__DIR__, "../assets/map/$(MAP_NAME).map")

    # fix number of crashes
    agents = [20, 40, 60, 80, 100]
    loops = collect(enumerate(Iterators.product(agents, 1:NUM_INS)))
    instances = Vector{Instance}(undef, length(loops))
    cnt_fin = Threads.Atomic{Int}(0)
    num_total_tasks = length(instances)
    Threads.@threads for (k, (N,)) in loops
        instances[k] = generate_random_sync_instance_grid_wellformed(;
            N = N,
            max_num_crashes = 1,
            filename = map_filename,
        )
        Threads.atomic_add!(cnt_fin, 1)
        print("\r$(cnt_fin[])/$(num_total_tasks) tasks have been finished")
    end
    println()
    JLD2.save(joinpath(root_dir, "fix_crash.jld2"), "instances", instances)
end

function create_benchmarks_exp4()
    seed!(1)
    NUM_INS = 25
    MAP_NAME = "warehouse-20-40-10-2-2"

    root_dir = joinpath(@__DIR__, "../../data/benchmark/exp4")
    map_filename = joinpath(@__DIR__, "../assets/map/$(MAP_NAME).map")

    # fix number of crashes
    agents = [20, 40, 60, 80, 100]
    loops = collect(enumerate(Iterators.product(agents, 1:NUM_INS)))
    instances = Vector{Instance}(undef, length(loops))
    cnt_fin = Threads.Atomic{Int}(0)
    num_total_tasks = length(instances)
    Threads.@threads for (k, (N,)) in loops
        instances[k] = generate_random_sync_instance_grid_wellformed(;
            N = N,
            max_num_crashes = 1,
            filename = map_filename,
        )
        Threads.atomic_add!(cnt_fin, 1)
        print("\r$(cnt_fin[])/$(num_total_tasks) tasks have been finished")
    end
    JLD2.save(joinpath(root_dir, "fix_crash.jld2"), "instances", instances)
end
