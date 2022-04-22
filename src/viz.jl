function plot_init()
    return plot(
        size = (400, 400),
        xticks = nothing,
        yticks = nothing,
        xaxis=false,
        yaxis=false
    )
end

function plot_graph!(G::Graph)
    positions = hcat(map(v -> v.pos, G)...)
    X = positions[1,:]
    Y = positions[2,:]

    # plot edges
    for v in G
        for j in filter(j -> j > v.id, v.neigh)
            u = get(G, j)
            plot!([v.pos[1], u.pos[1]], [v.pos[2], u.pos[2]], color=:black, label=nothing)
        end
    end

    # plot vertices
    ann = map(v -> (v.pos..., (string(v.id), 10)), G)  # annotation
    scatter!(X, Y, label=nothing, markersize=12, color=:white, annotations=ann)

    return plot!()
end

function plot_graph(G::Graph)
    plot_init()
    return plot_graph!(G)
end

function plot_config(G::Graph, config::Config, crashes::Crashes)
    plot_graph(G)
    for (agent, loc) = enumerate(config)
        v = get(G, loc)
        color = is_crashed(crashes, agent) ? :gray : :blue
        scatter!(
            [v.pos[1]], [v.pos[2]], marker=(12, 0.5, color), label=nothing,
            annotation=((v.pos + [0, 0.12])..., string(agent), color)
        )
    end

    return plot!()
end

# function plot_anim(
#     G::Graph,
#     hist::History;
#     interpolate_nums::Int = 0,
#     filename::String = "tmp.gif",
#     fps::Int64 = 3,
# )
#     N = length(hist[1][1])
#     anim = @animate for (k, (config, failures)) in enumerate(hist)
#         plot_config(V, config, failures)

#         # plot intermediate status
#         if k > 1 && interpolate_nums > 0
#             for i in 1:N
#                 vertex_now = V[config[i]]
#                 vertex_pre = V[hist[k-1][1][i]]
#                 vertex_now.id == vertex_pre.id && continue
#                 vec = (vertex_now.pos - vertex_pre.pos) / (interpolate_nums + 1)
#                 interpolate_positions = hcat(map(j -> vec * j + vertex_pre.pos, 1:interpolate_nums)...)
#                 X = interpolate_positions[1,:]
#                 Y = interpolate_positions[2,:]
#                 scatter!(X, Y, marker=(12, 0.2, :blue), label=nothing)
#             end
#         end
#     end
#     gif(anim, filename; fps=fps)
# end

export plot_graph, plot_config
