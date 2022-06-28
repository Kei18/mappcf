using MAPPFD
import YAML
import Dates
import JLD2
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
