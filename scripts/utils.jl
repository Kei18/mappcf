import YAML
import Dates
import JLD
using DataFrames
using Query
using Plots
import Statistics: mean, median

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

function load_benchmark(; name::String)::Union{Nothing,Vector{Instance}}
    if isdir(name)
        return JLD.load(joinpath(name, "benchmark.jld"))["instances"]
    elseif isfile(name)
        return JLD.load(name)["instances"]
    end
    @warn("neither file nor directory: $name")
    nothing
end

function load_benchmark(name::String)::Union{Nothing,Vector{Instance}}
    return load_benchmark(; name = name)
end

function plot_cactus(
    csv_filename::String;
    result_filename::String = joinpath(
        split(csv_filename, "/")[1:end-1]...,
        "cactus_plot.pdf",
    ),
)::Nothing
    df = CSV.File(csv_filename) |> DataFrame
    plot(
        xlims = (0, df |> @map(_.instance) |> collect |> maximum),
        ylims = (0, df |> @map(_.comp_time) |> collect |> maximum),
        xlabel = "solved instances",
        ylabel = "runtime (sec)",
        legend = :topleft,
    )
    for df_sub in groupby(df, :solver_index)
        Y =
            df_sub |>
            @filter(_.solved == true && _.verification == true) |>
            @map(_.comp_time) |>
            collect |>
            sort
        X = collect(1:length(Y))
        plot!(
            X,
            Y,
            linetype = :steppost,
            linewidth = 3,
            label = "$(df_sub[1,:solver_index]): $(df_sub[1,:solver])",
        )
    end
    safe_savefig!(result_filename)
    nothing
end

function describe_simply(
    csv_filename::String;
    VERBOSE::Int = 0,
    result_filename::String = joinpath(
        split(csv_filename, "/")[1:end-1]...,
        "stats_simple.txt",
    ),
)::Nothing

    df = CSV.File(csv_filename) |> DataFrame
    open(result_filename, "w") do out
        for df_sub in groupby(df, :solver_index)
            label = "$(df_sub[1,:solver_index]): $(df_sub[1,:solver])"
            y =
                df_sub |>
                @filter(_.solved == true && _.verification == true) |>
                @map(_.comp_time) |>
                collect
            s = "$label\tsolved:$(length(y))/$(first(size(df_sub)))"
            s *= "\tcomp_time:$(round(mean(y), digits=3)) (mean,sec)"
            s *= "\t$(round(median(y), digits=3)) (med,sec)"
            VERBOSE > 0 && println(s)
            println(out, s)
        end
    end
    nothing
end

function describe_all_stats(
    csv_filename::String;
    VERBOSE::Int = 0,
    result_filename::String = joinpath(split(csv_filename, "/")[1:end-1]..., "stats.txt"),
)::Nothing

    df = CSV.File(csv_filename) |> DataFrame
    open(result_filename, "w") do out
        for df_sub in groupby(df, :solver_index)
            label = "$(df_sub[1,:solver_index]): $(df_sub[1,:solver])"
            s =
                df_sub |>
                @filter(_.solved == true && _.verification == true) |>
                DataFrame |>
                describe |>
                string
            VERBOSE > 0 && println(label, "\n", s)
            println(out, label, "\n", s, "\n")
        end
    end
    nothing
end
