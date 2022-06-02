@testset verbose = true "examples" begin

    @testset "generate_random_instance_grid" begin
        ins = generate_random_sync_instance_grid()
        plot_instance(ins; show_agent_id = true, show_vertex_id = true)
        @test_savefig("random-sync-ins")

        ins = generate_random_seq_instance_grid()
        plot_instance(ins; show_agent_id = true, show_vertex_id = true)
        @test_savefig("random-seq-ins")
    end
end
