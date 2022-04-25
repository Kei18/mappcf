@testset "viz" begin
    G = generate_sample_graph1()
    config = Config([1, 4])
    crashes = Crashes([Crash(who = 1, loc = 1, when = 1)])

    plot_config(G, config, crashes, 1)
    safe_savefig!("./local/test-config.png")

    hist = History()
    push!(hist, (config = [1, 4], crashes = crashes))
    push!(hist, (config = [1, 2], crashes = crashes))
    push!(hist, (config = [1, 5], crashes = crashes))

    MAPPFD.plot_anim(G, hist; filename = "./local/test-anim.gif")
end
