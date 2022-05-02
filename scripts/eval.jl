import YAML
import Printf: @printf, @sprintf
import Dates
import Random: seed!
using MAPPFD
import Base.Threads

function main(config::Dict; pre_compile::Bool = false)

    # create result directory
    date_str = string(Dates.now())
    root_dir = joinpath(
        get(config, "root", joinpath(@__DIR__, "..", "..", "data", "exp")),
        date_str,
    )

    # instance generation
    seed_offset = get(config, "seed_offset", 0)
    num_instances = get(config, "num_instances", 3)

    @info @sprintf("generating %d instances", num_instances)
    instances = begin
        params = Dict([(Symbol(key), val) for (key, val) in config["instance"]])
        delete!(params, Symbol("_target_"))
        target = Meta.parse(config["instance"]["_target_"])
        seed!(seed_offset)
        map(e -> eval(target)(; params...), 1:num_instances)
    end

    num_solvers = length(get(config, "solvers", 0))
    num_total_tasks = num_instances * num_solvers
    cnt_fin = 0

    @info @sprintf("start solving with %d threads", Threads.nthreads())
    for k = 1:num_instances
        cnt_fin += num_solvers
        for (l, solver_info) in enumerate(get(config, "solvers", []))
            solver_name = solver_info["_target_"]
            solver = Meta.parse(solver_name)
            params = Dict([
                (Symbol(key), val) for
                (key, val) in filter(e -> e[1] != "_target_", solver_info)
            ])
            # t_planning = @elapsed begin
            # eval(solver)(instances[k]...)
            # end
        end
        @printf("\r%04d/%04d tasks have been finished", cnt_fin, num_total_tasks)
    end

    return instances
end

function main(args...)
    config_file = args[1]
    if !isfile(config_file)
        @warn @sprintf("%s does not exists", config_file)
        return
    end
    config = YAML.load_file(config_file)
    main(config)
end

main() = main(ARGS...)
