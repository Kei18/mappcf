function plot_init()
    return plot(
        size = (400, 400),
        xticks = nothing,
        yticks = nothing,
        xaxis = false,
        yaxis = false,
    )
end

function plot_graph!(G::Graph)
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
    ann = map(v -> (v.pos..., (string(v.id), 10)), _G)  # annotation
    scatter!(X, Y, label = nothing, markersize = 12, color = :white, annotations = ann)

    return plot!()
end

function plot_graph(G::Graph)
    plot_init()
    return plot_graph!(G)
end

function plot_config(G::Graph, config::Config, crashes::Crashes, t::Int)
    plot_graph(G)
    for (agent, loc) in enumerate(config)
        v = get(G, loc)
        color = is_crashed(crashes, agent, t) ? :gray : :blue
        scatter!(
            [v.pos[1]],
            [v.pos[2]],
            marker = (12, 0.5, color),
            label = nothing,
            annotation = ((v.pos + [0, 0.12])..., string(agent), color),
        )
    end

    return plot!()
end

function plot_anim(
    G::Graph,
    hist::History;
    interpolate_nums::Int = 2,
    filename::String = "tmp.gif",
    fps::Int64 = 3,
)
    N = length(hist[1].config)
    anim = @animate for (k, (config, crashes)) in enumerate(hist)
        plot_config(G, config, crashes, k)

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
                scatter!(X, Y, marker = (12, 0.2, :blue), label = nothing)
            end
        end
    end
    gif(anim, filename; fps = fps)
end

function safe_savefig!(filename::Union{Nothing,String} = nothing)
    isnothing(filename) && return
    dirname = join(split(filename, "/")[1:end-1], "/")
    !isdir(dirname) && mkpath(dirname)
    savefig(filename)
end

export plot_graph, plot_config, safe_savefig!
