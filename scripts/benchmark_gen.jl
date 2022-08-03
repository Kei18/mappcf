using MAPPFD
import YAML
import Dates
import JLD2
import Glob: glob
import Random: seed!
include("./utils.jl")

function create_benchmark(config_file::String, args...)::Union{Nothing,String}
    root_dir, config = prepare_exp!(config_file, "benchmark", args...)
    if !haskey(config, "benchmark")
        @error("no benchmark specification")
        return nothing
    end
    seed!(get(config, "seed", 0))
    instances = parse_fn(config["benchmark"])()
    if haskey(config, "viz")
        viz = parse_fn(config["viz"])
        for (k, ins) in enumerate(instances)
            viz(ins)
            safe_savefig!("$(root_dir)/instance_$(k).pdf")
        end
    end
    JLD2.save(joinpath(root_dir, "benchmark.jld2"), "instances", instances)
    return root_dir
end

function create_all_benchmarks(args...; dirname = "./scripts/config/benchmark")::Nothing
    files = glob(joinpath(dirname, "*.yaml"))
    for file in files
        create_benchmark(file, args...)
    end
end

function create_benchmarks_exp1()
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
