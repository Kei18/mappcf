macro test_savefig(name::String)
    return esc(quote
        filename = joinpath(DIRNAME, $name * ".png")
        MAPPFD.safe_savefig!(filename)
        @test isfile(filename)
    end)
end

@testset verbose = true "viz" begin
    import MAPPFD:
        generate_sample_graph1,
        generate_sample_graph4,
        plot_graph,
        safe_savefig!,
        SyncInstance,
        SeqInstance,
        plot_instance,
        SyncCrash,
        plot_config,
        Plan

    @testset "plot_graph" begin
        G = generate_sample_graph1()
        plot_graph(G)
        @test_savefig("graph")
    end

    @testset "plot_instance" begin
        ins = SyncInstance(MAPPFD.generate_sample_graph4(), [4, 8], [6, 2])
        plot_instance(ins)
        @test_savefig("sync-ins")

        ins = SeqInstance(MAPPFD.generate_sample_graph4(), [4, 8], [6, 2])
        plot_instance(ins)
        @test_savefig("seq-ins")
    end

    @testset "plot_config" begin
        G = generate_sample_graph1()
        config = [1, 4]
        goals = [3, 5]
        crashes = [SyncCrash(who = 1, loc = 1, when = 1)]
        plot_config(G, config, crashes)
        @test_savefig("config")
    end

    @testset "plot_paths" begin
        G = generate_sample_graph1()
        paths = [[1, 4, 2, 3], [4, 2, 5]]
        MAPPFD.plot_paths(G, paths)
        @test_savefig("paths")
    end

    @testset "plot_solution" begin
        ins = SyncInstance(MAPPFD.generate_sample_graph1(), [1, 4], [3, 5])
        solution = MAPPFD.Solution([
            [Plan(who = 1, path = [1, 2, 3], backup = Dict(), offset = 1)],
            [
                Plan(
                    who = 2,
                    path = [4, 1, 5],
                    backup = Dict(SyncCrash(when = 1, who = 1, loc = 1) => 2),
                    offset = 1,
                ),
                Plan(who = 2, path = [4, 2, 5], backup = Dict(), offset = 1),
            ],
        ])

        MAPPFD.plot_solution(ins, solution)
        @test_savefig("solution")
    end

    @testset "plot_anim" begin
        G = generate_sample_graph1()
        starts = [1, 4]
        goals = [3, 5]
        ins = SyncInstance(G, starts, goals)
        crashes = [SyncCrash(who = 1, loc = 1, when = 1)]

        hist = MAPPFD.History()
        push!(hist, (config = [1, 4], crashes = crashes))
        push!(hist, (config = [1, 2], crashes = crashes))
        push!(hist, (config = [1, 5], crashes = crashes))

        MAPPFD.plot_anim(ins, hist; filename = joinpath(DIRNAME, "anim.gif"))
    end
end
