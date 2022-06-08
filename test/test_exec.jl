@testset verbose = true "oracles" begin
    import MAPPFD: is_crashed, is_finished

    @testset "is_crashed" begin
        crashes = [SyncCrash(when = 1, who = 1, loc = 1)]
        @test is_crashed(crashes, 1)
        @test !is_crashed(crashes, 2)
    end

    @testset "is_finished" begin
        goals = [3, 5]
        @test !is_finished([1, 4], Vector{SyncCrash}(), goals)
        @test is_finished([1, 5], [SyncCrash(when = 1, who = 1, loc = 1)], goals)
    end

    @testset "sync / local FD" begin
        ins = generate_sample_sync_instance1()
        crashes = [SyncCrash(when = 1, who = 1, loc = 1)]
        solution = Solution([
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

        hist = execute_with_local_FD(ins, solution)
        @test map(e -> e.config[1], hist) == [1, 2, 3]
        @test map(e -> e.config[2], hist) == [4, 1, 5]

        hist = execute_with_local_FD(ins, solution; scheduled_crashes = crashes)
        @test map(e -> e.config[1], hist) == [1, 1, 1]
        @test map(e -> e.config[2], hist) == [4, 2, 5]

        seed!(1)
        @test approx_verify_with_local_FD(ins, solution; failure_prob = 0.5)

        # invalid
        solution = Solution([
            [Plan(who = 1, path = [1, 2, 3], backup = Dict(), offset = 1)],
            [Plan(who = 1, path = [4, 1, 5], backup = Dict(), offset = 1)],
        ])
        try
            execute_with_local_FD(ins, solution; scheduled_crashes = crashes)
            @test false
        catch e
            @test true
        end

        seed!(1)
        @test !approx_verify_with_local_FD(ins, solution; failure_prob = 0.5)
    end

    @testset "sync / local FD / no crash" begin
        ins = generate_sample_sync_instance1(0)
        crashes = [SyncCrash(when = 1, who = 1, loc = 1)]
        solution = Solution([
            [Plan(who = 1, path = [1, 2, 3], backup = Dict(), offset = 1)],
            [Plan(who = 1, path = [4, 1, 5], backup = Dict(), offset = 1)],
        ])
        hist = execute_with_local_FD(ins, solution; scheduled_crashes = crashes)
        @test !isnothing(hist)
    end

    @testset "sync / global FD" begin
        ins = SyncInstance(generate_sample_graph2(), [11, 22, 19], [15, 7, 9])

        solution = Solution([
            [
                Plan(
                    id = 1,
                    who = 1,
                    path = [11, 12, 13, 14, 15],
                    offset = 1,
                    backup = Dict(
                        SyncCrash(who = 3, loc = 14, when = 2) => 2,
                        SyncCrash(who = 1, loc = 12, when = 2) => 4,
                    ),
                ),
                Plan(
                    id = 2,
                    who = 1,
                    path = [11, 12, 11, 6, 1, 2, 3, 4, 5, 10, 15],
                    offset = 2,
                    backup = Dict(SyncCrash(who = 1, loc = 12, when = 2) => 3),
                ),
                Plan(id = 3, who = 1, path = [11, 12], offset = 2),
                Plan(id = 4, who = 1, path = [11, 12], offset = 2),
            ],
            [
                Plan(
                    id = 1,
                    who = 2,
                    path = [22, 17, 12, 7],
                    offset = 1,
                    backup = Dict(
                        SyncCrash(who = 3, loc = 14, when = 2) => 2,
                        SyncCrash(who = 1, loc = 12, when = 2) => 4,
                    ),
                ),
                Plan(
                    id = 2,
                    who = 2,
                    path = [22, 17, 12, 7],
                    offset = 2,
                    backup = Dict(SyncCrash(who = 1, loc = 12, when = 2) => 3),
                ),
                Plan(id = 3, who = 2, path = [22, 17, 16, 11, 6, 7], offset = 2),
                Plan(id = 4, who = 2, path = [22, 17, 16, 11, 6, 7], offset = 2),
            ],
            [
                Plan(
                    id = 1,
                    who = 3,
                    path = [19, 14, 9],
                    offset = 1,
                    backup = Dict(
                        SyncCrash(who = 3, loc = 14, when = 2) => 2,
                        SyncCrash(who = 1, loc = 12, when = 2) => 4,
                    ),
                ),
                Plan(
                    id = 2,
                    who = 3,
                    path = [19, 14],
                    offset = 2,
                    backup = Dict(SyncCrash(who = 1, loc = 12, when = 2) => 3),
                ),
                Plan(id = 3, who = 3, path = [19, 14], offset = 2),
                Plan(id = 4, who = 3, path = [19, 14, 9], offset = 2),
            ],
        ])

        hist = execute_with_global_FD(ins, solution)
        @test map(e -> e.config[1], hist) == [11, 12, 13, 14, 15]
        @test map(e -> e.config[2], hist) == [22, 17, 12, 7, 7]
        @test map(e -> e.config[3], hist) == [19, 14, 9, 9, 9]

        crashes = [SyncCrash(who = 1, loc = 12, when = 2)]
        hist = execute_with_global_FD(ins, solution; scheduled_crashes = crashes)
        @test map(e -> e.config[1], hist) == [11, 12, 12, 12, 12, 12]
        @test map(e -> e.config[2], hist) == [22, 17, 16, 11, 6, 7]
        @test map(e -> e.config[3], hist) == [19, 14, 9, 9, 9, 9]

        seed!(1)
        @test approx_verify_with_global_FD(ins, solution)
    end

    @testset "seq / local FD" begin
        ins = generate_sample_seq_instance4()
        solution = Solution([
            [
                Plan(
                    id = 1,
                    who = 1,
                    path = [4, 5, 6],
                    offset = 1,
                    backup = Dict(SeqCrash(who = 2, loc = 5) => 2),
                ),
                Plan(id = 2, who = 1, path = [4, 2, 6], offset = 1),
            ],
            [
                Plan(
                    id = 1,
                    who = 2,
                    path = [8, 5, 2],
                    offset = 1,
                    backup = Dict(SeqCrash(who = 1, loc = 5) => 2),
                ),
                Plan(id = 2, who = 2, path = [8, 6, 2], offset = 1),
            ],
        ])

        seed!(1)
        hist = execute_with_local_FD(ins, solution)
        @test !isnothing(hist)
        @test map(e -> e.config[1], hist) == [4, 5, 6, 6, 6]
        @test map(e -> e.config[2], hist) == [8, 8, 8, 5, 2]

        seed!(1)
        hist = execute_with_local_FD(
            ins,
            solution,
            scheduled_crashes = [SeqCrash(who = 1, loc = 5)],
        )
        @test !isnothing(hist)
        @test map(e -> e.config[1], hist) == [4, 5, 5, 5]
        @test map(e -> e.config[2], hist) == [8, 8, 6, 2]

        @test approx_verify_with_local_FD(ins, solution)
    end
end
