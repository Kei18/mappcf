@testset verbose = true "oracles" begin
    import Random: seed!
    import MAPPFD:
        is_crashed, is_finished, is_colliding, SyncCrash, Plan, approx_verification

    G = MAPPFD.generate_sample_graph1()
    starts = [1, 4]
    goals = [3, 5]
    ins = MAPPFD.SyncInstance(G, starts, goals)
    crashes = [SyncCrash(when = 1, who = 1, loc = 1)]

    @testset "is_crashed" begin
        @test is_crashed(crashes, 1, 2)
        @test !is_crashed(crashes, 2, 1)
    end

    @testset "is_finished" begin
        @test !is_finished([1, 4], Vector{SyncCrash}(), goals, 1)
        @test is_finished([1, 5], crashes, goals, 3)
    end

    @testset "is_colliding" begin
        @test is_colliding([1, 2, 3], [1, 1, 3])
        @test is_colliding([1, 2, 3], [1, 3, 2])
        @test !is_colliding([1, 2, 3], [4, 5, 6])
    end

    @testset "sync, execute_with_local_FD" begin
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

        hist = MAPPFD.execute_with_local_FD(ins, solution)
        @test map(e -> e.config[1], hist) == [1, 2, 3]
        @test map(e -> e.config[2], hist) == [4, 1, 5]

        hist = MAPPFD.execute_with_local_FD(ins, solution; crashes = crashes)
        @test map(e -> e.config[1], hist) == [1, 1, 1]
        @test map(e -> e.config[2], hist) == [4, 2, 5]

        # invalid
        solution = MAPPFD.Solution([
            [Plan(who = 1, path = [1, 2, 3], backup = Dict(), offset = 1)],
            [Plan(who = 1, path = [4, 1, 5], backup = Dict(), offset = 1)],
        ])
        hist = MAPPFD.execute_with_local_FD(ins, solution; crashes = crashes)
        @test isnothing(hist)
    end

    @testset "sync_verification" begin
        solution = MAPPFD.Solution([
            [Plan(who = 1, path = [1, 2, 3], backup = Dict(), offset = 1)],
            [
                Plan(
                    who = 2,
                    path = [4, 1, 5],
                    backup = Dict((when = 1, who = 1, loc = 1) => 2),
                    offset = 1,
                ),
                Plan(who = 2, path = [4, 2, 5], backup = Dict(), offset = 1),
            ],
        ])
        @test approx_verification(ins, solution; failure_prob = 0.5)

        solution = MAPPFD.Solution([
            [Plan(who = 1, path = [1, 2, 3], backup = Dict(), offset = 1)],
            [Plan(who = 2, path = [4, 1, 5], backup = Dict(), offset = 1)],
        ])
        seed!(1)
        @test !approx_verification(ins, solution; failure_prob = 0.5)
    end

    # @testset "sync_global_verification" begin
    #     solution = (
    #         paths = [[1, 2, 3], [4, 1, 5]],
    #         time_offset = 1,
    #         backups = Dict(
    #             Crash(who = 1, when = 1, loc = 1) =>
    #                 (paths = [[1], [4, 2, 5]], time_offset = 1, backups = ()),
    #         ),
    #     )
    #     seed!(1)
    #     @test sync_global_verification(ins..., solution; failure_prob = 0.5)

    #     solution = (paths = [[1, 2, 3], [4, 1, 5]], time_offset = 1, backups = Dict())
    #     seed!(1)
    #     @test !sync_global_verification(ins..., solution; failure_prob = 0.5)
    # end
end
