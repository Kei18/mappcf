@testset verbose = true "oracles" begin
    G = generate_sample_graph1()
    config = Config([1, 4])
    crashes = Crashes([Crash(who = 1, loc = 1)])

    @testset "occupancy" begin
        @test is_occupied(config, 1) == true
        @test is_occupied(config, 2) == false
    end

    @testset "crash" begin
        @test is_crashed(crashes, 1) == true
        @test is_crashed(crashes, 2) == false
    end

    @testset "non-anonymous failure detector" begin
        @test non_anonymous_failure_detector(crashes, 1, 1) == true
        @test non_anonymous_failure_detector(crashes, 1, 2) == false
        @test non_anonymous_failure_detector(crashes, 2, 1) == false
    end
end
