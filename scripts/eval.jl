import CSV
import Random: seed!
using MAPPFD
import Base.Threads
include("./utils.jl")


function main(config_file::String)
    res = prepare_exp!(config_file)
    isnothing(res) && return
    root_dir, config = res

    # instance generation
    seed!(get(config, "seed_offset", 0))
    instances = parse_fn(config["instances"])()
    @info("generate $(length(instances)) instances")

    num_solvers = length(get(config, "solvers", 0))
    num_total_tasks = length(instances) * num_solvers
    verify = parse_fn(config["verification"])

    # cnt_fin = 0
    result = []
    for (k, ins) in enumerate(instances)
        for (l, solver_info) in enumerate(get(config, "solvers", []))
            solver_name = solver_info["_target_"]
            planner = parse_fn(solver_info)
            t_planning = @elapsed begin
                solution = planner(ins)
            end
            if !verify(ins, solution)
                @warn("found infeasible solution: ins-$k, solver-$l")
                return :error
            end
            push!(
                result,
                (
                    instance = k,
                    N = length(ins.starts),
                    solver = solver_name,
                    solver_index = l,
                    solved = !isnothing(solution),
                    comp_time = t_planning,
                ),
            )
            if get(config, "save_plot", false)
                plot_solution(ins, solution; show_vertex_id = true, show_agent_id = true)
                safe_savefig!("$(root_dir)/solution_$(solver_name)-$(l)_$(k).pdf")
            end
        end
    end

    @info("save result")
    CSV.write(joinpath(root_dir, "result.csv"), result)
    return :success
end
