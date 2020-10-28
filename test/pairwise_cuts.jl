@testset "src/util/pairwise_cuts.jl" begin
    data = WaterModels.parse_file("../test/data/epanet/multinetwork/owf-hw-lps.inp")
    mn_data = WaterModels.make_multinetwork(data)

    @testset "_PairwiseCutProblem instantiation" begin
        wm = instantiate_model(mn_data, LRDWaterModel, build_mn_wf)
        JuMP.set_optimizer(wm.model, cbc) # Explicitly set an optimizer.
        vid_1 = WaterModels._VariableIndex(1, :pump, :z_pump, 1)
        vid_2 = WaterModels._VariableIndex(1, :pipe, :y_pipe, 2)
        problem = WaterModels._PairwiseCutProblem(_MOI.MIN_SENSE, vid_1, vid_2, 0.0)

        @test problem.sense === _MOI.MIN_SENSE
        @test problem.variable_index_1 == vid_1
        @test problem.variable_index_2 == vid_2
        @test problem.variable_2_fixing_value == 0.0
    end

    @testset "_optimize_bound_problem!" begin
        wm = instantiate_model(mn_data, LRDWaterModel, build_mn_wf)
        JuMP.set_optimizer(wm.model, cbc) # Explicitly set an optimizer.
        vid_1 = WaterModels._VariableIndex(1, :pump, :z_pump, 1)
        vid_2 = WaterModels._VariableIndex(1, :pipe, :y_pipe, 2)
        problem = WaterModels._PairwiseCutProblem(_MOI.MIN_SENSE, vid_1, vid_2, 0.0)
        termination_status = WaterModels._optimize_bound_problem!(wm, problem)
        @test termination_status === OPTIMAL
    end

    @testset "_get_bound_problem_candidate! (minimization)" begin
        wm = instantiate_model(mn_data, LRDWaterModel, build_mn_wf)
        JuMP.set_optimizer(wm.model, cbc) # Explicitly set an optimizer.
        vid_1 = WaterModels._VariableIndex(1, :pump, :z_pump, 1)
        vid_2 = WaterModels._VariableIndex(1, :pipe, :y_pipe, 2)
        problem = WaterModels._PairwiseCutProblem(_MOI.MIN_SENSE, vid_1, vid_2, 0.0)
        @test WaterModels._get_bound_problem_candidate(wm, problem) == 0.0
    end

    @testset "_get_bound_problem_candidate! (maximization)" begin
        wm = instantiate_model(mn_data, LRDWaterModel, build_mn_wf)
        JuMP.set_optimizer(wm.model, cbc) # Explicitly set an optimizer.
        vid_1 = WaterModels._VariableIndex(1, :pump, :z_pump, 1)
        vid_2 = WaterModels._VariableIndex(1, :pipe, :y_pipe, 2)
        problem = WaterModels._PairwiseCutProblem(_MOI.MAX_SENSE, vid_1, vid_2, 0.0)
        @test WaterModels._get_bound_problem_candidate(wm, problem) == 1.0
    end

    @testset "_get_bound_problem_candidate! (maximization, no solution)" begin
        wm = instantiate_model(mn_data, LRDWaterModel, build_mn_wf)
        JuMP.set_optimizer(wm.model, cbc) # Explicitly set an optimizer.
        vid_1 = WaterModels._VariableIndex(1, :pipe, :y_pipe, 1)
        vid_2 = WaterModels._VariableIndex(1, :pump, :z_pump, 1)
        problem = WaterModels._PairwiseCutProblem(_MOI.MAX_SENSE, vid_1, vid_2, 1.0)
        @test WaterModels._get_bound_problem_candidate(wm, problem) == 1.0
    end

    @testset "_solve_bound_problem!" begin
        wm = instantiate_model(mn_data, LRDWaterModel, build_mn_wf)
        JuMP.set_optimizer(wm.model, cbc) # Explicitly set an optimizer.
        vid_1 = WaterModels._VariableIndex(1, :pump, :z_pump, 1)
        vid_2 = WaterModels._VariableIndex(1, :pipe, :y_pipe, 2)
        problem = WaterModels._PairwiseCutProblem(_MOI.MIN_SENSE, vid_1, vid_2, 0.0)
        @test WaterModels._solve_bound_problem!(wm, problem) == 0.0
    end
end
