"""
utility functions to summarize results
mostly used in early development
"""

using DataFrames
using Query
using Plots
using StatsPlots
import CSV
import Statistics: mean, median

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
            if !isempty(y)
                s *= "\tcomp_time:$(round(mean(y), digits=3)) (mean,sec)"
                s *= "\t$(round(median(y), digits=3)) (med,sec)"
            end
            VERBOSE > 0 && println(s)
            println(out, s)
        end
    end
    nothing
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

function plot_runtime_vs_max_num_crashes(
    csv_filename::String;
    VERBOSE::Int = 0,
    result_dir::String = joinpath(split(csv_filename, "/")[1:end-1]...),
)::Nothing
    df = CSV.File(csv_filename) |> DataFrame
    for df_sub in groupby(df, :solver_index)
        plot(
            xlims = (-0.5, 0.5 + (df_sub |> @map(_.max_num_crashes) |> maximum)),
            ylims = (0, :auto),
            ylabel = "runtime (sec)",
            xlabel = "max_num_crashes",
            title = "$(df_sub[1,:solver_index]):$(df_sub[1,:solver])",
        )
        for D in groupby(
            df_sub |> @filter(_.solved == true && _.verification == true) |> DataFrame,
            :max_num_crashes,
        )
            M = hcat((D |> @map([_.max_num_crashes, _.comp_time]) |> collect)...)
            X, Y = M[1, :], M[2, :]
            violin!(X, Y, color = :deepskyblue, label = nothing)
            boxplot!(
                X,
                Y,
                label = nothing,
                color = :azure1,
                fillalpha = 0.75,
                bar_width = 0.2,
            )
        end
        safe_savefig!(
            joinpath(
                result_dir,
                "runtime_vs_max_num_crashes_solver-$(df_sub[1, :solver_index]).pdf",
            ),
        )
    end
end

function plot_success_rate_vs_max_num_crashes(
    csv_filename::String;
    VERBOSE::Int = 0,
    result_dir::String = joinpath(split(csv_filename, "/")[1:end-1]...),
)::Nothing
    df = CSV.File(csv_filename) |> DataFrame
    for df_sub in groupby(df, :solver_index)
        plot(
            ylims = (0, 1.1),
            ylabel = "success rate",
            xlabel = "max_num_crashes",
            title = "$(df_sub[1,:solver_index]):$(df_sub[1,:solver])",
        )
        for D in groupby(df_sub, :max_num_crashes)
            X = D[1, :][:max_num_crashes]
            num_all = D |> @count
            num_solved = D |> @filter(_.solved == true && _.verification == true) |> @count
            Y = num_solved / num_all
            bar!([X], [Y], label = nothing, color = :deepskyblue)
            annotate!([X], [1.1], ["$num_solved/$num_all"], fontsize = 12)
        end
        safe_savefig!(
            joinpath(
                result_dir,
                "success_rate_vs_max_num_crashes_solver-$(df_sub[1, :solver_index]).pdf",
            ),
        )
    end
end

function open_result_dir(csv_filename::String)::Nothing
    dir = joinpath(split(csv_filename, "/")[1:end-1]...)
    run(`open $dir`)
    nothing
end

function plot_failure_reasons(
    csv_filename::String;
    VERBOSE::Int = 0,
    result_dir::String = joinpath(split(csv_filename, "/")[1:end-1]...),
)::Nothing

    df = CSV.File(csv_filename) |> DataFrame
    for df_sub in groupby(df, :solver_index)
        arr_max_num_crashes =
            df_sub |> @map(_.max_num_crashes) |> @unique() |> collect |> sort
        arr_failure_type =
            df_sub |>
            @filter(!isna(_.failure_type)) |>
            @map(_.failure_type) |>
            @unique() |>
            x -> get.(x) |> collect
        D = fill(0.0, (length(arr_max_num_crashes), length(arr_failure_type)))
        for (k, max_num_crashes) in enumerate(arr_max_num_crashes)
            for (l, failure_type) in enumerate(arr_failure_type)
                y =
                    df_sub |>
                    @filter(
                        _.max_num_crashes == max_num_crashes &&
                        _.failure_type == failure_type
                    ) |>
                    @count
                y_total = df_sub |> @filter(_.max_num_crashes == max_num_crashes) |> @count
                D[k, l] = y / y_total
            end
        end
        label = reshape(
            map(s -> string(s)[9:end], arr_failure_type),
            (1, length(arr_failure_type)),
        )
        groupedbar(
            D,
            bar_position = :stack,
            xticks = arr_max_num_crashes,
            label = label,
            legend = :topleft,
            xlabel = "max_num_crashes",
            ylabel = "failure rate",
            ylims = (0, 1),
            barwidth = 0.3,
        )
        safe_savefig!(
            joinpath(result_dir, "failure-reason_solver-$(df_sub[1, :solver_index]).pdf"),
        )
    end
end

function plot_N_vs_runtime(
    csv_filename::String;
    result_dir::String = joinpath(split(csv_filename, "/")[1:end-1]...),
)::Nothing

    df = CSV.File(csv_filename) |> DataFrame
    for df_sub in groupby(df, :solver_index)
        plot(xlabel = "N", ylabel = "runtime (sec)", legend = :topleft)
        for df_subsub in groupby(df_sub, :max_num_crashes)
            X, Y = [], []
            arr_N = df_subsub |> @map(_.N) |> collect |> sort
            for N in arr_N
                y =
                    df_subsub |>
                    @filter(_.N == N && _.solved == true) |>
                    @map(_.comp_time) |>
                    collect |>
                    mean
                push!(Y, y)
                push!(X, N)
            end
            plot!(X, Y, linewidth = 3, label = "crasehs: $(df_subsub[1,:max_num_crashes])")
        end

        # all
        X, Y = [], []
        arr_N = df_sub |> @map(_.N) |> collect |> sort
        for N in arr_N
            y =
                df_sub |>
                @filter(_.N == N && _.solved == true) |>
                @map(_.comp_time) |>
                collect |>
                mean
            push!(Y, y)
            push!(X, N)
        end
        plot!(X, Y, linewidth = 5, color = :black, label = "all")

        safe_savefig!(
            joinpath(result_dir, "N_vs_runtime_solver-$(df_sub[1, :solver_index]).pdf"),
        )
    end
end

function plot_N_vs_success_rate(
    csv_filename::String;
    result_filename::String = joinpath(
        split(csv_filename, "/")[1:end-1]...,
        "success_rate_per_agents.pdf",
    ),
)
    df = CSV.File(csv_filename) |> DataFrame
    plot(ylims = (0, 1.0), ylabel = "success rate", xlabel = "N")
    # all
    for df_sub in groupby(df, :solver_index)
        X, Y = [], []
        arr_N = df_sub |> @map(_.N) |> collect |> sort
        for N in arr_N
            y =
                (df_sub |> @filter(_.N == N && _.solved == true) |> @count) /
                (df_sub |> @filter(_.N == N) |> @count)
            push!(Y, y)
            push!(X, N)
        end
        label = "$(df_sub[1,:solver_index]):$(df_sub[1,:solver])"
        plot!(X, Y, linewidth = 3, label = label)
    end
    safe_savefig!(result_filename)
end

function plot_runtime_profile(
    csv_filename::String;
    result_filename::String = joinpath(
        split(csv_filename, "/")[1:end-1]...,
        "runtime_profile.pdf",
    ),
)
    df = CSV.File(csv_filename) |> DataFrame
    D = Vector{Vector{Real}}()
    labels = nothing
    for df_sub in groupby(df, :solver_index)
        df_subsub =
            df_sub |> @filter(_.solved) |> @select(startswith("elapsed_")) |> DataFrame
        labels = vcat("others", names(df_subsub))
        scores = vcat(mean.(eachcol(df_subsub)))
        push!(
            D,
            vcat(
                (df_sub |> @filter(_.solved) |> @map(_.comp_time) |> mean) - sum(scores),
                scores,
            ),
        )
    end
    D = transpose(hcat(D...))
    solver_names = map(e -> "$(first(e))", unique(df[:, :solver_index]))

    groupedbar(
        D,
        bar_position = :stack,
        bar_width = 0.7,
        label = reshape(labels, (1, length(labels))),
        xlabel = "solver",
        ylabel = "runtime (sec)",
        xticks = (1:length(unique(df[:, :solver_index])), solver_names),
        legend = :bottom,
    )
    safe_savefig!(result_filename)
end

function plot_success_rate_matrix(
    csv_filename::String;
    result_dir::String = joinpath(split(csv_filename, "/")[1:end-1]...),
    VERBOSE::Int = 0,
)
    df_origin = CSV.File(csv_filename) |> DataFrame
    for df in groupby(df_origin, :solver_index)
        solver_name = "$(df[1,:solver_index]):$(df[1,:solver])"
        VERBOSE > 0 && println("solver:$(solver_name)")
        N_min = df |> @map(_.N) |> minimum
        N_max = df |> @map(_.N) |> maximum
        arr_N = vcat(collect(N_min:5:N_max), N_max)
        arr_max_num_crashes = df |> @map(_.max_num_crashes) |> @unique() |> collect |> sort
        D = fill(0.0, (length(arr_max_num_crashes), length(arr_N) - 1))
        for k = 1:length(arr_N)-1
            N1, N2 = arr_N[k], arr_N[k+1]
            for (l, max_num_crashes) in enumerate(arr_max_num_crashes)
                cnt_total =
                    df |>
                    @filter(N1 <= _.N <= N2 && _.max_num_crashes == max_num_crashes) |>
                    collect |>
                    length
                cnt_success =
                    df |>
                    @filter(
                        N1 <= _.N <= N2 &&
                        _.max_num_crashes == max_num_crashes &&
                        _.solved == true
                    ) |>
                    collect |>
                    length
                D[l, k] = cnt_success / cnt_total
                VERBOSE > 0 && println(
                    "N=$(N1)-$(N2)\tcrash=$(max_num_crashes)" *
                    "\tcnt_total=$cnt_total" *
                    "\tcnt_success=$(cnt_success)" *
                    "\tsuccess=$(D[l,k])",
                )
            end
        end

        heatmap(
            D,
            xticks = (
                1:length(arr_N)-1,
                map(k -> "$(arr_N[k])-$(arr_N[k+1])", 1:length(arr_N)-1),
            ),
            ylabel = "max_num_crashes",
            xlabel = "N",
            c = :grayC,
            title = "success_rate of $solver_name",
        )

        safe_savefig!(
            joinpath(result_dir, "success_rate_matrix-$(df[1, :solver_index]).png"),
        )
    end
end
