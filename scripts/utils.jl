import YAML
import Dates
import JLD2

function parse_fn(config::Dict)::Function
    params = Dict()
    for (key, val) in config
        params[Symbol(key)] = isa(val, Dict) ? parse_fn(val) : val
    end
    delete!(params, Symbol("_target_"))
    target = Meta.parse(config["_target_"])
    return (args...; kwargs...) -> eval(target)(args...; params..., kwargs...)
end

function prepare_exp!(
    config_file::String,
    label::String = "exp",
    args...,
)::Union{Nothing,Tuple{String,Dict}}
    @assert(isfile(config_file), "$config_file does not exist")
    config = YAML.load_file(config_file)

    # rewrite configuration
    for arg in args
        param_name, val = split(arg, "=")[1:2]
        keys = split(param_name, ".")
        C = config
        for (k, key) in enumerate(keys)
            if haskey(C, key)
                if k < length(keys)
                    C = C[key]
                end
            else
                @error("$(config_file) does not have $(keys)")
                return nothing
            end
        end

        # parse
        val_parsed = tryparse(Int64, val)
        if isnothing(val_parsed)
            val_parsed = tryparse(Float64, val)
        end
        if isnothing(val_parsed)
            val_parsed = tryparse(Bool, val)
        end
        if isnothing(val_parsed)
            val_parsed = string(val)
        end
        C[keys[end]] = val_parsed
    end

    date_str = replace(string(Dates.now()), ":" => "-")
    root_dir = joinpath(
        get(config, "root", joinpath(@__DIR__, "..", "..", "data", label)),
        date_str,
    )
    @info("result will be saved in $root_dir")
    !isdir(root_dir) && mkpath(root_dir)
    additional_info = Dict(
        "git_hash" => read(`git log -1 --pretty=format:"%H"`, String),
        "date" => date_str,
    )
    YAML.write_file(joinpath(root_dir, "config.yaml"), merge(config, additional_info))
    return (root_dir, config)
end

function load_benchmark(;
    name::String,
    map_name::String,
    num::Union{Nothing,Int} = nothing,
)::Vector{Instance}
    G = MAPPFD.load_mapf_bench(map_name)
    instances = Vector{Instance}
    if isdir(name)
        instances = JLD2.load(joinpath(name, "benchmark.jld2"))["instances"]
    elseif isfile(name)
        instances = JLD2.load(name)["instances"]
    end
    instances = instances[1:(isnothing(num) ? end : num)]
    foreach(ins -> foreach(v -> push!(ins.G, v), G), instances)
    return instances
end
