const COLORS = collect(ColorSchemes.seaborn_bright)

function get_colors(N::Int)::Vector{ColorTypes.RGB{Float64}}
    N <= length(COLORS) && return COLORS[1:N]
    return vcat(map(_ -> COLORS, 1:ceil(Int, N / length(COLORS)))...)[1:N]
end

function get_color(i::Int64)::ColorTypes.RGB{Float64}
    return COLORS[mod1(i, length(COLORS))]
end

function safe_savefig!(filename::Union{Nothing,String} = nothing)
    isnothing(filename) && return
    dirname = join(split(filename, "/")[1:end-1], "/")
    !isdir(dirname) && mkpath(dirname)
    savefig(filename)
end

function plot_init(; figsize::Real = 400, kwargs...)
    return plot(
        size = (figsize, figsize),
        xticks = nothing,
        yticks = nothing,
        xaxis = false,
        yaxis = false,
    )
end

function plot_graph!(
    G::Graph;
    show_vertex_id::Bool = false,
    markersize::Real = 12,
    fontsize::Real = 6,
    kwargs...,
)
    # plot edges
    for v in G
        for j in filter(j -> j > v.id, v.neigh)
            u = get(G, j)
            plot!(
                [v.pos[1], u.pos[1]],
                [v.pos[2], u.pos[2]],
                color = :black,
                label = nothing,
            )
        end
    end

    # plot vertices, remove redundant vertices
    _G = filter(v -> !isempty(v.neigh), G)
    positions = hcat(map(v -> v.pos, _G)...)
    X = positions[1, :]
    Y = positions[2, :]
    scatter!(X, Y, label = nothing, markersize = markersize, color = :white)
    show_vertex_id && annotate!(X, Y, map(v -> (v.id, fontsize, :black, :bottom), _G))

    return plot!()
end

function plot_graph(args...; kwargs...)
    plot_init(; kwargs...)
    return plot_graph!(args...; kwargs...)
end

function plot_locs!(
    G::Graph,
    config::Config;
    markersize::Real = 12,
    show_agent_id::Bool = false,
    fontsize::Real = 6,
    kwargs...,
)
    positions = hcat(map(k -> get(G, k).pos, config)...)
    X = positions[1, :]
    Y = positions[2, :]
    scatter!(
        X,
        Y,
        color = get_colors(length(config)),
        marker = (markersize, 1.0),
        label = nothing,
    )
    show_agent_id &&
        annotate!(X, Y, map(k -> (k, fontsize, :black, :top), 1:length(config)))
end

function plot_goals!(G::Graph, goals::Config; markersize_goal::Real = 5, kwargs...)
    isempty(goals) && return
    positions = hcat(map(k -> get(G, k).pos, goals)...)
    X = positions[1, :]
    Y = positions[2, :]
    return scatter!(
        X,
        Y,
        label = nothing,
        markersize = markersize_goal,
        markershape = :rect,
        color = get_colors(length(goals)),
    )
end

function plot_instance(G::Graph, starts::Config, goals::Config; kwargs...)
    plot_graph(G; kwargs...)
    plot_locs!(G, starts; kwargs...)
    plot_goals!(G, goals; kwargs...)
    return plot!()
end

function plot_instance(ins::Instance; kwargs...)
    return plot_instance(ins.G, ins.starts, ins.goals; kwargs...)
end

function plot_instance(ins::Tuple{Graph,Config,Config}; kwargs...)
    return plot_instance(ins...; kwargs...)
end

function plot_crashes!(G::Graph, config::Config, crashes::Vector{T} where {T<:Crash})
    positions = hcat(
        map(
            k -> get(G, config[k]).pos,
            filter(k -> is_crashed(crashes, k), 1:length(config)),
        )...,
    )
    isempty(positions) && return plot!()
    return scatter!(
        positions[1, :],
        positions[2, :],
        label = nothing,
        markersize = 8,
        markershape = :diamond,
        markercolor = :lightgray,
    )
end

function plot_config(
    G::Graph,
    config::Config,
    crashes::Vector{T} = Vector{T}();
    show_agent_id::Bool = false,
    show_vertex_id::Bool = false,
) where {T<:Crash}
    plot_graph(G; show_vertex_id = show_vertex_id)
    plot_locs!(G, config; show_agent_id = show_agent_id)
    plot_crashes!(G, config, crashes)
    return plot!()
end

function plot_paths(
    G::Graph,
    paths::Paths;
    show_vertex_id::Bool = false,
    show_agent_id::Bool = false,
    linewidth::Real = 2,
    δ = 0.02,
    kwargs...,
)
    plot_instance(
        G,
        map(first, paths),
        map(last, paths);
        show_agent_id = show_agent_id,
        show_vertex_id = show_vertex_id,
        kwargs...,
    )
    for (i, path) in enumerate(paths)
        δ_fixed = rand() * 2δ - δ
        positions = hcat(map(k -> get(G, k).pos + [δ_fixed, δ_fixed], path)...)
        plot!(
            positions[1, :],
            positions[2, :],
            label = nothing,
            color = get_color(i),
            linewidth = linewidth,
        )
    end

    return plot!()
end

function plot_solution(
    G::Graph,
    starts::Config,
    goals::Config,
    solution::Solution,
    ;
    linewidth = 6,
    δ = 0.02,
    ϵ = 0.4,
    kwargs...,
)
    plot_instance(G, starts, goals; kwargs...)
    isnothing(solution) && return plot!()
    N = length(starts)
    for i = 1:N
        δ_fixed = rand() * 2δ - δ
        for (k, plan) in enumerate(solution[i])
            positions = hcat(map(k -> get(G, k).pos + [δ_fixed, δ_fixed], plan.path)...)
            X = positions[1, :][plan.offset:end]
            Y = positions[2, :][plan.offset:end]
            plot!(
                X,
                Y,
                label = nothing,
                color = get_color(i),
                linewidth = linewidth * (ϵ^(k - 1)),
            )
        end
    end
    plot!()
end

function plot_solution(ins::Instance, solution::Solution; kwargs...)
    return plot_solution(ins.G, ins.starts, ins.goals, solution; kwargs...)
end

function plot_anim(
    G::Graph,
    hist::History;
    interpolate_nums::Int = 2,
    filename::String = "tmp.gif",
    fps::Int64 = 3,
    show_agent_id::Bool = false,
    show_vertex_id::Bool = false,
    goals::Union{Nothing,Config} = nothing,
)
    N = length(hist[1].config)
    anim = @animate for (k, (config, crashes)) in enumerate(hist)
        plot_config(
            G,
            config,
            crashes;
            show_agent_id = show_agent_id,
            show_vertex_id = show_vertex_id,
        )
        !isnothing(goals) && plot_goals!(G, goals)

        # plot intermediate status
        if k > 1 && interpolate_nums > 0
            for i = 1:N
                vertex_now = get(G, config[i])
                vertex_pre = get(G, hist[k-1].config[i])
                vertex_now.id == vertex_pre.id && continue
                vec = (vertex_now.pos - vertex_pre.pos) / (interpolate_nums + 1)
                interpolate_positions =
                    hcat(map(j -> vec * j + vertex_pre.pos, 1:interpolate_nums)...)
                X = interpolate_positions[1, :]
                Y = interpolate_positions[2, :]
                scatter!(X, Y, marker = (12, 0.2, get_color(i)), label = nothing)
            end
        end
    end
    gif(anim, filename; fps = fps)
end

function plot_anim(ins::Instance, hist::History; kwargs...)
    return plot_anim(ins.G, hist; goals = ins.goals, kwargs...)
end
