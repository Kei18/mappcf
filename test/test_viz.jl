@testset "viz" begin
    G = generate_sample_graph1()
    config = Config([1, 4])
    crashes = Crashes([Crash(who = 1, loc = 1)])

    plot_config(G, config, crashes)
    safe_savefig!("./local/test-config.png")

    hist = History()
    crash = Crash(who = 1, loc = 1)
    push!(hist, (config = [1, 4], crashes = [crash]))
    push!(hist, (config = [1, 2], crashes = [crash]))
    push!(hist, (config = [1, 5], crashes = [crash]))

    MAPPFD.plot_anim(G, hist; filename = "./local/test-anim.gif")
end
