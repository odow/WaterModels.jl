# Define common CRD (continuous or convex relaxation- and direction-based) implementations
# of water distribution network constraints, which use directed flow variables.


########################################## PIPES ##########################################


function constraint_pipe_head_loss(
    wm::AbstractCRDModel, n::Int, a::Int, node_fr::Int, node_to::Int, exponent::Float64,
    L::Float64, r::Float64, q_max_reverse::Float64, q_min_forward::Float64)
    # Gather directed flow and head difference variables.
    qp, qn = var(wm, n, :qp_pipe, a), var(wm, n, :qn_pipe, a)
    dhp, dhn = var(wm, n, :dhp_pipe, a), var(wm, n, :dhn_pipe, a)

    # Add relaxed constraints for head loss in the positive and negative directions.
    c_1 = JuMP.@NLconstraint(wm.model, r * head_loss(qp) <= dhp / L)
    c_2 = JuMP.@NLconstraint(wm.model, r * head_loss(qn) <= dhn / L)

    # Add linear upper bounds on the above convex relaxations.
    rhs_p = r * JuMP.upper_bound(qp)^(exponent - 1.0) * qp
    c_3 = JuMP.@constraint(wm.model, dhp / L <= rhs_p)
    rhs_n = r * JuMP.upper_bound(qn)^(exponent - 1.0) * qn
    c_4 = JuMP.@constraint(wm.model, dhn / L <= rhs_n)

    # Append the :pipe_head_loss constraint array.
    append!(con(wm, n, :pipe_head_loss)[a], [c_1, c_2, c_3, c_4])
end


function constraint_on_off_des_pipe_head_loss(
    wm::AbstractCRDModel, n::Int, a::Int, node_fr::Int, node_to::Int, exponent::Float64,
    L::Float64, r::Float64, q_max_reverse::Float64, q_min_forward::Float64)
    # Gather directed flow and head difference variables.
    qp, qn = var(wm, n, :qp_des_pipe, a), var(wm, n, :qn_des_pipe, a)
    dhp, dhn = var(wm, n, :dhp_des_pipe, a), var(wm, n, :dhn_des_pipe, a)

    # Add relaxed constraints for head loss in the positive and negative directions.
    c_1 = JuMP.@NLconstraint(wm.model, r * head_loss(qp) <= dhp / L)
    c_2 = JuMP.@NLconstraint(wm.model, r * head_loss(qn) <= dhn / L)

    # Add linear upper bounds on the above convex relaxations.
    rhs_p = r * JuMP.upper_bound(qp)^(exponent - 1.0) * qp
    c_3 = JuMP.@constraint(wm.model, dhp / L <= rhs_p)
    rhs_n = r * JuMP.upper_bound(qn)^(exponent - 1.0) * qn
    c_4 = JuMP.@constraint(wm.model, dhn / L <= rhs_n)

    # Append the :on_off_des_pipe_head_loss constraint array.
    append!(con(wm, n, :on_off_des_pipe_head_loss)[a], [c_1, c_2, c_3, c_4])
end


########################################## PUMPS ##########################################


function constraint_on_off_pump_head_gain(wm::AbstractCRDModel, n::Int, a::Int, node_fr::Int, node_to::Int, q_min_forward::Float64)
    # Gather pump flow, head gain, and status variables.
    qp, g, z = var(wm, n, :qp_pump, a), var(wm, n, :g_pump, a), var(wm, n, :z_pump, a)

    # Define the (relaxed) head gain relationship for the pump.
    head_curve_func_z = _calc_head_curve_function(ref(wm, n, :pump, a), z)
    c_1 = JuMP.@constraint(wm.model, g <= head_curve_func_z(qp))
    
    # Add a constraint that lower-bounds the head gain variable.
    head_curve_func = _calc_head_curve_function(ref(wm, n, :pump, a))
    qp_ub, qp_lb = JuMP.upper_bound(qp), q_min_forward
    f_1, f_2 = head_curve_func(q_min_forward), head_curve_func(JuMP.upper_bound(qp))
    gain_lb_expr = (f_2 - f_1) / (qp_ub - qp_lb) * (qp - qp_lb * z) + f_1 * z
    c_2 = JuMP.@constraint(wm.model, gain_lb_expr <= g)

    # Append the :on_off_pump_head_gain constraint array.
    append!(con(wm, n, :on_off_pump_head_gain)[a], [c_1, c_2])
end


function constraint_on_off_pump_power(wm::AbstractCRDModel, n::Int, a::Int, q_min_forward::Float64)
    # Gather pump flow, power, and status variables.
    q, P, z = var(wm, n, :qp_pump, a), var(wm, n, :P_pump, a), var(wm, n, :z_pump, a)

    # Compute pump flow and power partitioning.
    q_lb, q_ub = q_min_forward, JuMP.upper_bound(q)
    f_ua = _calc_pump_power_ua(wm, n, a, [q_lb, q_ub])

    if f_ua[1] != f_ua[2]
        # Build a linear under-approximation of the power.
        slope = (f_ua[2] - f_ua[1]) / (q_ub - q_lb)
        power_expr = slope * (q - q_lb * z) + f_ua[1] * z
        c = JuMP.@constraint(wm.model, power_expr <= P)
        append!(con(wm, n, :on_off_pump_power)[a], [c])
    end
end