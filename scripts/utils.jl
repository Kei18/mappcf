import YAML
import Dates

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
)::Tuple{String,Dict}
    @assert(isfile(config_file), "$config_file does not exist")
    config = YAML.load_file(config_file)

    # rewrite configuration
    for arg in args
        param_name, val = split(arg, "=")[1:2]
        keys = split(param_name, ".")
        C = config
        for key in keys[1:end-1]
            if haskey(C, key)
                C = C[key]
            else
                @error("$(config_file) does not have $(keys)")
                return nothing
            end
        end
        val_parsed = tryparse(Int64, val)
        if isnothing(val_parsed)
            val_parsed = tryparse(Float64, val)
        end
        if isnothing(val_parsed)
            val_parsed = val
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
