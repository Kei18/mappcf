using MAPPFD
import YAML
import Dates
import JLD
include("./utils.jl")

function create_benchmark(config_file::String)::Union{Nothing,String}
    root_dir, config = prepare_exp!(config_file, "benchmark")
    if !haskey(config, "benchmark")
        @error("no benchmark specification")
        return nothing
    end
    instances = parse_fn(config["benchmark"])()
    JLD.save(joinpath(root_dir, "benchmark.jld"), "instances", instances)
    return root_dir
end

function load_benchmark(name::String)::Union{Nothing,Vector{Instance}}
    if isdir(name)
        return JLD.load(joinpath(name, "benchmark.jld"))["instances"]
    elseif isfile(name)
        return JLD.load(name)["instances"]
    end
    @warn("neither file nor directory: $name")
    nothing
end