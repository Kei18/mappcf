import CSV
import Random: seed!
import Printf: @printf
using MAPPFD
import JLD
import Base.Threads
include("./utils.jl")

function main(config_file::String, args...)
    res = prepare_exp!(config_file, "exp", args...)
    isnothing(res) && return
    root_dir, config = res

    # instance generation
    seed!(get(config, "seed_offset", 0))
    instances = parse_fn(config["instances"])()
    @info("generate $(length(instances)) instances")

    num_solvers = length(get(config, "solvers", 0))
    num_total_tasks = length(instances) * num_solvers
    verify = parse_fn(config["verification"])
    time_limit_sec = get(config, "time_limit_sec", 10)

    run =
        (instances; is_pre_compile::Bool = false) -> begin
            result = Array{Any}(undef, num_total_tasks)
            cnt_fin = Threads.Atomic{Int}(0)
            loops = collect(
                enumerate(
                    Iterators.product(
                        enumerate(instances),
                        enumerate(get(config, "solvers", [])),
                    ),
                ),
            )
            Threads.@threads for (m, ((k, ins), (l, solver_info))) in loops
                solver_name = solver_info["_target_"]
                planner = parse_fn(solver_info)
                t_planning = @elapsed begin
                    solution = planner(ins; time_limit_sec = time_limit_sec)
                end
                verification = verify(ins, solution)
                if !verification
                    @error("found infeasible solution: ins-$k, solver-$l")
                    JLD.save(
                        joinpath(root_dir, "infeasible_ins-$(k)_solver-$(l).jld"),
                        "ins",
                        ins,
                    )
                end
                result[m] = (
                    instance = k,
                    N = length(ins.starts),
                    max_num_crashes = isnothing(ins.max_num_crashes) ?
                                      length(ins.starts) - 1 : ins.max_num_crashes,
                    solver = solver_name,
                    solver_index = l,
                    solved = !isa(solution, Failure),
                    failure_type = isa(solution, Failure) ? string(solution) : "",
                    verification = verification,
                    comp_time = t_planning,
                    (; get_scores(ins, solution)...)...,
                )
                if !is_pre_compile &&
                   Threads.nthreads() == 1 &&
                   !isa(solution, Failure) &&
                   get(config, "save_plot", false)
                    plot_solution(ins, solution; show_vertex_id = true, show_agent_id = true)
                    safe_savefig!("$(root_dir)/solution_$(solver_name)-$(l)_$(k).pdf")
                end
                Threads.atomic_add!(cnt_fin, 1)
                !is_pre_compile && @printf(
                    "\r%04d/%04d tasks have been finished",
                    cnt_fin[],
                    num_total_tasks
                )
            end
            !is_pre_compile && println()
            return result
        end

    # pre-compile
    @info("pre-compiling")
    run(instances[1:1]; is_pre_compile = true)
    @info("start $(num_total_tasks) tasks with $(Threads.nthreads()) threads")
    elapsed_exp = @elapsed begin
        result = run(instances)
    end
    @info("done ($(elapsed_exp) sec), save result")
    result_filename = joinpath(root_dir, "result.csv")
    CSV.write(result_filename, result)

    # stats
    if haskey(config, "summary")
        @info("compute stats")
        foreach(c -> parse_fn(c)(result_filename), config["summary"])
    end
    return :success
end
