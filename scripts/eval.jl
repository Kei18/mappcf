import YAML
import CSV
import Printf: @printf, @sprintf
import Dates
import Random: seed!
using MAPPFD
import Base.Threads

function main(config::Dict)

    # create result directory
    date_str = string(Dates.now())
    root_dir = joinpath(
        get(config, "root", joinpath(@__DIR__, "..", "..", "data", "exp")),
        date_str,
    )

    @info @sprintf("result will be saved in %s", root_dir)
    !isdir(root_dir) && mkpath(root_dir)
    additional_info = Dict(
        "git_hash" => read(`git log -1 --pretty=format:"%H"`, String),
        "date" => date_str,
    )
    YAML.write_file(joinpath(root_dir, "config.yaml"), merge(config, additional_info))

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

    verification = Meta.parse(config["verification"]["_target_"])
    verification_params = Dict([
        (Symbol(key), val) for
        (key, val) in filter(e -> e[1] != "_target_", config["verification"])
    ])

    cnt_fin = 0
    result = []
    for (k, ins) in enumerate(instances)
        for (l, solver_info) in enumerate(get(config, "solvers", []))
            # planning
            solver_name = solver_info["_target_"]
            solver = Meta.parse(solver_name)
            params = Dict([
                (Symbol(key), val) for
                (key, val) in filter(e -> e[1] != "_target_", solver_info)
            ])
            t_planning = @elapsed begin
                solution = eval(solver)(ins...; params...)
            end
            # verification
            if !eval(verification)(ins..., solution; verification_params...)
                println()
                @warn(
                    @sprintf(
                        "found infeasible solution: ins-%d, %s (%d)",
                        k,
                        solver_name,
                        l
                    )
                )
                return :error
            end
            # record result
            push!(
                result,
                (
                    instance = k,
                    N = length(ins[2]),
                    solver = solver_name,
                    solver_index = l,
                    solved = !isnothing(solution),
                    comp_time = t_planning,
                ),
            )
            # visualize
            if get(config, "save_plot", false)
                MAPPFD.plot_solution(
                    ins...,
                    solution;
                    show_vertex_id = true,
                    show_agent_id = true,
                )
                MAPPFD.safe_savefig!("$(root_dir)/solution_$(solver_name)_$(k).pdf")
            end
            cnt_fin += 1
        end
        @printf("\r%04d/%04d tasks have been finished", cnt_fin, num_total_tasks)
    end

    @info("save result")
    CSV.write(joinpath(root_dir, "result.csv"), result)

    return :success
end

function main(args...)
    config_file = args[1]
    if !isfile(config_file)
        @warn @sprintf("%s does not exists", config_file)
        return config_file
    end
    config = YAML.load_file(config_file)
    main(config)
end

main() = main(ARGS...)
