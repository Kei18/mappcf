@testset verbose = true "examples" begin
    @testset "get_scores" begin
        ins = generate_sample_sync_instance1()
        solution = [
            [
                Plan(who = 1, offset = 1, path = [1, 2, 3]),
                Plan(who = 1, offset = 1, path = [1, 4, 2, 5, 2, 3]),
                Plan(who = 1, offset = 1, path = [1, 1, 1, 1, 1, 2, 3]),
            ],
            [Plan(who = 2, offset = 1, path = [4, 4, 2, 5])],
        ]

        scores = get_scores(ins, solution)
        @test scores[:sum_of_shortest_path_lengths] == 4
        @test scores[:max_shortest_path_lengths] == 2
        @test scores[:primary_max_path_length] == 2
        @test scores[:primary_sum_of_path_length] == 4
        @test scores[:primary_max_traveling_time] == 3
        @test scores[:primary_sum_of_traveling_time] == 5
        @test scores[:worst_max_path_length] == 5
        @test scores[:worst_sum_of_path_length] == 7
        @test scores[:worst_max_traveling_time] == 6
        @test scores[:worst_sum_of_traveling_time] == 9
    end
end
