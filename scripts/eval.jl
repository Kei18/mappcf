import CSV
import Random: seed!
import Printf: @printf
using MAPPFD
import JLD
import Base.Threads
include("./utils.jl")

function main(config_file::String, args...)
    timer = Deadline(time_limit_sec = 0)
    res = prepare_exp!(config_file, "exp", args...)
    isnothing(res) && return
    root_dir, config = res
    VERBOSE = get(config, "VERBOSE", 0)

    # instance generation
    seed!(get(config, "seed_offset", 0))
    instances = parse_fn(config["instances"])()
    verbose(VERBOSE, 1, timer, "generate $(length(instances)) instances")

    num_solvers = length(get(config, "solvers", 0))
    num_total_tasks = length(instances) * num_solvers
    verify = parse_fn(config["verification"])
    visualize =
        haskey(config, "visualization") ? parse_fn(config["visualization"]) : nothing
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
                    runtime_profile = Dict{Symbol,Real}()
                    solution = planner(
                        ins;
                        time_limit_sec = time_limit_sec,
                        runtime_profile = runtime_profile,
                    )
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
                    (; runtime_profile...)...,
                )
                if !is_pre_compile &&
                   Threads.nthreads() == 1 &&
                   !isa(solution, Failure) &&
                   !isnothing(visualize)
                    visualize(ins, solution)
                    safe_savefig!("$(root_dir)/solution_$(solver_name)-$(l)_$(k).pdf")
                end
                Threads.atomic_add!(cnt_fin, 1)
                !is_pre_compile && verbose(
                    VERBOSE,
                    1,
                    timer,
                    "$(cnt_fin[])/$(num_total_tasks) tasks have been finished";
                    CR = true,
                    LF = false,
                )
            end
            !is_pre_compile && println()
            return result
        end

    # pre-compile
    verbose(VERBOSE, 1, timer, "pre-compiling")
    run(instances[1:1]; is_pre_compile = true)
    verbose(
        VERBOSE,
        1,
        timer,
        "start $(num_total_tasks) tasks with $(Threads.nthreads()) threads",
    )
    elapsed_exp = @elapsed begin
        result = run(instances)
    end
    VERBOSE > 0 && println()
    verbose(VERBOSE, 1, timer, "done ($(elapsed_exp) sec), save result")
    result_filename = joinpath(root_dir, "result.csv")
    CSV.write(result_filename, result)

    # stats
    if haskey(config, "summary")
        verbose(VERBOSE, 1, timer, "compute stats")
        foreach(c -> parse_fn(c)(result_filename), config["summary"])
    end

    verbose(VERBOSE, 1, timer, "finish evaluation")
    return :success
end
