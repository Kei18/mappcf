@testset verbose = true "examples" begin
    using MAPPFD:
        generate_random_instance_grid,
        generate_random_instance,
        plot_instance,
        safe_savefig!

    @testset "generate_random_instance_grid" begin
        plot_instance(generate_random_instance_grid()...)
        safe_savefig!("./local/test-random-ins-grid.png")
    end

    @testset "generate_random_instance" begin
        plot_instance(generate_random_instance()...)
        safe_savefig!("./local/test-random-ins.png")
    end
end
