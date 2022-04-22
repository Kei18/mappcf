using Test
using MAPPFD

@testset "oracles" begin
    G = MAPPFD.generate_sample_graph1()
    config = Config([1, 4])
    crashes = Crashes([Crash(who=1, loc=1)])

    target_agent = 1
    target_loc = 1

    # occupancy
    @test is_occupied(config, 1) == true
    @test is_occupied(config, 2) == false

    # crash
    @test is_crashed(crashes, 1) == true
    @test is_crashed(crashes, 2) == false

    # non-anonymous failure detector (where, who)
    @test non_anonymous_failure_detector(crashes, 1, 1) == true
    @test non_anonymous_failure_detector(crashes, 1, 2) == false
    @test non_anonymous_failure_detector(crashes, 2, 1) == false
end
