@testset verbose = true "oracles" begin
    using MAPPFD: is_occupied, is_finished, non_anonymous_failure_detector

    G = generate_sample_graph1()
    config = Config([1, 4])
    goals = Config([3, 5])
    crashes = Crashes([Crash(when = 1, who = 1, loc = 1)])

    @testset "occupancy" begin
        @test is_occupied(config, 1) == true
        @test is_occupied(config, 2) == false
    end

    @testset "crash" begin
        @test is_crashed(crashes, 1, 2) == true
        @test is_crashed(crashes, 2, 1) == false
    end

    @testset "non-anonymous failure detector" begin
        @test non_anonymous_failure_detector(crashes, 1, 1) == true
        @test non_anonymous_failure_detector(crashes, 1, 2) == false
        @test non_anonymous_failure_detector(crashes, 2, 1) == false
    end

    @testset "is_finished" begin
        @test is_finished([1, 4], Crashes(), goals, 1) == false
        @test is_finished([1, 5], crashes, goals, 3) == true
    end

    @testset "synchronous_execute" begin
        solution = MAPPFD.Solution([
            [(path = [1, 2, 3], backup = Dict(), time_offset = 1)],
            [
                (
                    path = [4, 1, 5],
                    backup = Dict((when = 1, who = 1, loc = 1) => 2),
                    time_offset = 1,
                ),
                (path = [4, 2, 5], backup = Dict(), time_offset = 1),
            ],
        ])

        hist = MAPPFD.synchronous_execute(G, solution, goals)
        @test map(e -> e.config[1], hist) == [1, 2, 3]
        @test map(e -> e.config[2], hist) == [4, 1, 5]

        hist = MAPPFD.synchronous_execute(G, solution, goals; crashes = crashes)
        @test map(e -> e.config[1], hist) == [1, 1, 1]
        @test map(e -> e.config[2], hist) == [4, 2, 5]
    end
end
