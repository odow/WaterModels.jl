@testset "Network Expansion Problems" begin
    @testset "Shamir network (reduced), CNLP formulation." begin
        data = parse_file("../test/data/epanet/shamir.inp")
        modifications = parse_file("../test/data/json/shamir-reduced.json")
        InfrastructureModels.update_data!(data, modifications)
        @test_throws ErrorException instantiate_model(data, CNLPWaterModel, post_ne)
    end

    @testset "Shamir network (reduced), MICP-E formulation." begin
        data = parse_file("../test/data/epanet/shamir.inp")
        modifications = parse_file("../test/data/json/shamir-reduced.json")
        InfrastructureModels.update_data!(data, modifications)
        wm = instantiate_model(data, MICPEWaterModel, post_ne)

        f_1 = Juniper.register(head_loss_args(wm)..., autodiff=false)
        f_2 = Juniper.register(primal_energy_args(wm)..., autodiff=false)
        f_3 = Juniper.register(dual_energy_args(wm)..., autodiff=false)

        juniper = JuMP.optimizer_with_attributes(Juniper.Optimizer,
            "nl_solver"=>ipopt, "registered_functions"=>[f_1, f_2, f_3],
            "log_levels"=>[])
        solution = _IM.optimize_model!(wm, optimizer=juniper)

        @test solution["termination_status"] == LOCALLY_SOLVED
        @test isapprox(solution["objective"], 1.36e6, rtol=1.0e-4)
    end

    @testset "Shamir network (reduced), MICP-R formulation." begin
        data = parse_file("../test/data/epanet/shamir.inp")
        modifications = parse_file("../test/data/json/shamir-reduced.json")
        InfrastructureModels.update_data!(data, modifications)
        wm = instantiate_model(data, MICPRWaterModel, post_ne)

        f = Juniper.register(head_loss_args(wm)..., autodiff=false)
        juniper = JuMP.optimizer_with_attributes(Juniper.Optimizer,
            "nl_solver"=>ipopt, "registered_functions"=>[f], "log_levels"=>[])
        solution = _IM.optimize_model!(wm, optimizer=juniper)

        @test solution["termination_status"] == LOCALLY_SOLVED
        @test isapprox(solution["objective"], 1.36e6, rtol=1.0e-4)
    end

    @testset "Shamir network, MILP formulation." begin
        data = parse_file("../test/data/epanet/shamir.inp")
        modifications = parse_file("../test/data/json/shamir-reduced.json")
        InfrastructureModels.update_data!(data, modifications)

        wm = instantiate_model(data, MILPRWaterModel, post_ne, ext=Dict(:num_breakpoints => 5))
        solution = _IM.optimize_model!(wm, optimizer=cbc)

        @test solution["termination_status"] == OPTIMAL
        @test isapprox(solution["objective"], 1.36e6, rtol=1.0e-4)
    end

    @testset "Shamir network (reduced), MILP-R formulation." begin
        data = parse_file("../test/data/epanet/shamir.inp")
        modifications = parse_file("../test/data/json/shamir-reduced.json")
        InfrastructureModels.update_data!(data, modifications)

        wm = instantiate_model(data, MILPRWaterModel, post_ne, ext=Dict(:num_breakpoints => 5))
        solution = _IM.optimize_model!(wm, optimizer=cbc)

        @test solution["termination_status"] == OPTIMAL
        @test isapprox(solution["objective"], 1.36e6, rtol=1.0e-4)
    end

    @testset "Shamir network (reduced), NCNLP formulation." begin
        data = parse_file("../test/data/epanet/shamir.inp")
        modifications = parse_file("../test/data/json/shamir-reduced.json")
        InfrastructureModels.update_data!(data, modifications)
        wm = instantiate_model(data, NCNLPWaterModel, post_ne)

        f = Juniper.register(head_loss_args(wm)..., autodiff=false)
        juniper = JuMP.optimizer_with_attributes(Juniper.Optimizer,
            "nl_solver"=>ipopt, "registered_functions"=>[f], "log_levels"=>[])
        solution = _IM.optimize_model!(wm, optimizer=juniper)

        @test solution["termination_status"] == LOCALLY_SOLVED
        @test isapprox(solution["objective"], 1.36e6, rtol=1.0e-4)
    end
end
