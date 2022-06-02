import YAML
import Dates

function parse_fn(config::Dict)::Function
    params = Dict()
    for (key, val) in config
        params[Symbol(key)] = isa(val, Dict) ? parse_fn(val) : val
    end
    delete!(params, Symbol("_target_"))
    target = Meta.parse(config["_target_"])
    return (args...) -> eval(target)(args...; params...)
end

function prepare_exp!(config_file::String, label::String = "exp")::Tuple{String,Dict}
    @assert(isfile(config_file), "$config_file does not exist")
    config = YAML.load_file(config_file)
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
