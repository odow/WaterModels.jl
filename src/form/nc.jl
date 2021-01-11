# Define NC (nonconvex nonlinear programming) implementations of water distribution
# feasibility and optimization problem specifications. Note that here, ``nonconvex
# nonlinear'' describes the treatment of head loss and head gain constraints, which are
# nonlinear equalities. NC formulations also include nonlinearites that would be surmised in
# a full problem formulation (e.g., in the optimal water flow problem, a cubic function of
# flow is used in this formulation to define the consumption of power by active pumps).

# Constraints and variables common to all formulations with undirected flows.
# In these formulations, the variable q correspond to flow between i and j.
# When q is nonnegative, flow is assumed to travel from i to j. When q is
# negative, flow is assumed to travel from j to i.


"Create flow-related variables common to all directed flow models for edge-type components."
function variable_flow(wm::AbstractNCModel; nw::Int=wm.cnw, bounded::Bool=true, report::Bool=true)
    for name in ["des_pipe", "pipe", "pump", "regulator", "short_pipe", "valve"]
        # Create undirected flow variables for each component.
        _variable_component_flow(wm, name; nw=nw, bounded=bounded, report=report)
    end
end


"Create flow variables that are common to all directed flow models for a component."
function _variable_component_flow(
    wm::AbstractNCModel, component_name::String; nw::Int=wm.cnw,
    bounded::Bool=true, report::Bool=true)
    # Store the corresponding component symbol.
    comp_sym = Symbol(component_name)

    # Initialize the variables. (The default start value of _FLOW_MIN is crucial.)
    q = var(wm, nw)[Symbol("q_" * component_name)] = JuMP.@variable(wm.model,
        [a in ids(wm, nw, comp_sym)], base_name="$(nw)_q_$(component_name)",
        start=comp_start_value(ref(wm, nw, comp_sym, a), "q_start", _FLOW_MIN))

    if bounded # If the variables are bounded, apply the bounds.
        for (a, comp) in ref(wm, nw, comp_sym)
            JuMP.set_lower_bound(q[a], comp["flow_min"])
            JuMP.set_upper_bound(q[a], comp["flow_max"])
        end
    end

    # Initialize the solution reporting data structures.
    report && sol_component_value(wm, nw, comp_sym, :q, ids(wm, nw, comp_sym), q)
end


function constraint_pipe_flow(wm::AbstractNCModel, n::Int, a::Int, q_max_reverse::Float64, q_min_forward::Float64)
    # By default, there are no constraints, here.
end


function constraint_pipe_head(wm::AbstractNCModel, n::Int, a::Int, node_fr::Int, node_to::Int)
    # Get head variables for from and to nodes.
    h_i, h_j = var(wm, n, :h, node_fr), var(wm, n, :h, node_to)

    # For pipes, the differences must satisfy lower and upper bounds.
    dh_lb = JuMP.lower_bound(h_i) - JuMP.upper_bound(h_j)
    c_1 = JuMP.@constraint(wm.model, h_i - h_j >= dh_lb)
    dh_ub = JuMP.upper_bound(h_i) - JuMP.lower_bound(h_j)
    c_2 = JuMP.@constraint(wm.model, h_i - h_j <= dh_ub)

    # Append the constraint array.
    append!(con(wm, n, :pipe_head, a), [c_1, c_2])
end

"Adds head loss constraint for a pipe in the `NC` formulation."
function constraint_pipe_head_loss(
    wm::NCWaterModel, n::Int, a::Int, node_fr::Int, node_to::Int, exponent::Float64,
    L::Float64, r::Float64, q_max_reverse::Float64, q_min_forward::Float64)
    # Gather flow and head variables included in head loss constraints.
    q, h_i, h_j = var(wm, n, :q_pipe, a), var(wm, n, :h, node_fr), var(wm, n, :h, node_to)

    # Add nonconvex constraint for the head loss relationship.
    c_1 = JuMP.@NLconstraint(wm.model, r * head_loss(q) <= inv(L) * (h_i - h_j))
    c_2 = JuMP.@NLconstraint(wm.model, r * head_loss(q) >= inv(L) * (h_i - h_j))

    # Append the :pipe_head_loss constraint array.
    append!(con(wm, n, :pipe_head_loss)[a], [c_1, c_2])
end


function constraint_on_off_des_pipe_flow(wm::AbstractNCModel, n::Int, a::Int, q_max_reverse::Float64, q_min_forward::Float64)
    # Get flow and design status variables.
    q, z = var(wm, n, :q_des_pipe, a), var(wm, n, :z_des_pipe, a)

    # If the valve is closed, flow must be zero.
    q_lb, q_ub = JuMP.lower_bound(q), JuMP.upper_bound(q)
    c_1 = JuMP.@constraint(wm.model, q >= q_lb * z)
    c_2 = JuMP.@constraint(wm.model, q <= q_ub * z)

    # Append the constraint array.
    append!(con(wm, n, :on_off_des_pipe_flow, a), [c_1, c_2])
end


function constraint_on_off_des_pipe_head(wm::AbstractNCModel, n::Int, a::Int, node_fr::Int, node_to::Int)
    # Get head variables for from and to nodes.
    h_i, h_j = var(wm, n, :h, node_fr), var(wm, n, :h, node_to)

    # For pipes, the differences must satisfy lower and upper bounds.
    dh_lb = JuMP.lower_bound(h_i) - JuMP.upper_bound(h_j)
    c_1 = JuMP.@constraint(wm.model, h_i - h_j >= dh_lb)
    dh_ub = JuMP.upper_bound(h_i) - JuMP.lower_bound(h_j)
    c_2 = JuMP.@constraint(wm.model, h_i - h_j <= dh_ub)

    # Append the constraint array.
    append!(con(wm, n, :on_off_des_pipe_head, a), [c_1, c_2])
end


"Adds head loss constraint for a design pipe in the `NC` formulation."
function constraint_on_off_des_pipe_head_loss(
    wm::AbstractNCModel, n::Int, a::Int, node_fr::Int, node_to::Int, exponent::Float64,
    L::Float64, r::Float64, q_max_reverse::Float64, q_min_forward::Float64)
    # Get flow and design status variables.
    q, z = var(wm, n, :q_des_pipe, a), var(wm, n, :z_des_pipe, a)

    # Gather flow and head variables included in head loss constraints.
    h_i, h_j = var(wm, n, :h, node_fr), var(wm, n, :h, node_to)

    # Add nonconvex constraint for the head loss relationship.
    c_1 = JuMP.@NLconstraint(wm.model, r * head_loss(q) <= inv(L) * z * (h_i - h_j))
    c_2 = JuMP.@NLconstraint(wm.model, r * head_loss(q) >= inv(L) * z * (h_i - h_j))

    # Append the :pipe_head_loss constraint array.
    append!(con(wm, n, :on_off_des_pipe_head_loss)[a], [c_1, c_2])
end


function constraint_des_pipe_flow(wm::AbstractNCModel, n::Int, node_fr::Int, node_to::Int, des_pipes::Array{Int64,1})
    # For undirected formulations, there are no constraints, here.
end


function constraint_des_pipe_head(wm::AbstractNCModel, n::Int, node_fr::Int, node_to::Int, des_pipes::Array{Int64,1})
    # For undirected formulations, there are no constraints, here.
end


function constraint_on_off_pump_flow(wm::AbstractNCModel, n::Int, a::Int, q_min_forward::Float64)
    # Get pump status variable.
    q, z = var(wm, n, :q_pump, a), var(wm, n, :z_pump, a)

    # If the pump is inactive, flow must be zero.
    q_ub = JuMP.upper_bound(q)
    c_1 = JuMP.@constraint(wm.model, q >= q_min_forward * z)
    c_2 = JuMP.@constraint(wm.model, q <= q_ub * z)

    # Append the constraint array.
    append!(con(wm, n, :on_off_pump_flow, a), [c_1, c_2])
end


function constraint_on_off_pump_head(wm::AbstractNCModel, n::Int, a::Int, node_fr::Int, node_to::Int)
    # Get head variables for from and to nodes.
    h_i, h_j = var(wm, n, :h, node_fr), var(wm, n, :h, node_to)

    # Get pump status variable.
    g, z = var(wm, n, :g_pump, a), var(wm, n, :z_pump, a)

    # If the pump is off, decouple the head difference relationship. If the pump is on,
    # ensure the head difference is equal to the pump's head gain (i.e., `g`).
    dhn_ub = JuMP.upper_bound(h_j) - JuMP.lower_bound(h_i)
    dhn_lb = JuMP.lower_bound(h_j) - JuMP.upper_bound(h_i)
    c_1 = JuMP.@constraint(wm.model, h_j - h_i <= g + dhn_ub * (1.0 - z))
    c_2 = JuMP.@constraint(wm.model, h_j - h_i >= g + dhn_lb * (1.0 - z))

    # Append the constraint array.
    append!(con(wm, n, :on_off_pump_head, a), [c_1, c_2])
end


"Adds head gain constraints for pumps in `NC` formulations."
function constraint_on_off_pump_head_gain(wm::AbstractNCModel, n::Int, a::Int, node_fr::Int, node_to::Int, q_min_forward::Float64)
    # Gather pump flow, head gain, and status variables.
    q, g, z = var(wm, n, :q_pump, a), var(wm, n, :g_pump, a), var(wm, n, :z_pump, a)

    # Add constraint equating head gain with respect to the pump curve.
    head_curve_func = _calc_head_curve_function(ref(wm, n, :pump, a), z)
    c_1 = JuMP.@constraint(wm.model, head_curve_func(q) <= g)
    c_2 = JuMP.@constraint(wm.model, head_curve_func(q) >= g)

    # Append the :on_off_pump_head_gain constraint array.
    append!(con(wm, n, :on_off_pump_head_gain)[a], [c_1, c_2])
end


function constraint_on_off_regulator_flow(wm::AbstractNCModel, n::Int, a::Int, q_min_forward::Float64)
    # Get flow and regulator status variables.
    q, z = var(wm, n, :q_regulator, a), var(wm, n, :z_regulator, a)

    # If the regulator is closed, flow must be zero.
    q_lb, q_ub = max(JuMP.lower_bound(q), q_min_forward), JuMP.upper_bound(q)
    c_1 = JuMP.@constraint(wm.model, q >= q_lb * z)
    c_2 = JuMP.@constraint(wm.model, q <= q_ub * z)

    # Append the constraint array.
    append!(con(wm, n, :on_off_regulator_flow, a), [c_1, c_2])
end


function constraint_on_off_regulator_head(wm::AbstractNCModel, n::Int, a::Int, node_fr::Int, node_to::Int, head_setting::Float64)
    # Get regulator status variable.
    z = var(wm, n, :z_regulator, a)

    # Get head variables for from and to nodes (i.e., `i` and `j`).
    h_i, h_j = var(wm, n, :h, node_fr), var(wm, n, :h, node_to)

    # When the pressure reducing valve is open, the head at node j is predefined.
    h_lb, h_ub = JuMP.lower_bound(h_j), JuMP.upper_bound(h_j)
    c_1 = JuMP.@constraint(wm.model, h_j >= (1.0 - z) * h_lb + z * head_setting)
    c_2 = JuMP.@constraint(wm.model, h_j <= (1.0 - z) * h_ub + z * head_setting)

    # When the pressure reducing valve is open, the head loss is nonnegative.
    dh_lb = JuMP.lower_bound(h_i) - JuMP.upper_bound(h_j)
    c_3 = JuMP.@constraint(wm.model, h_i - h_j >= dh_lb * (1.0 - z))
    dh_ub = JuMP.upper_bound(h_i) - JuMP.lower_bound(h_j)
    c_4 = JuMP.@constraint(wm.model, h_i - h_j <= dh_ub * z)

    # Append the constraint array.
    append!(con(wm, n, :on_off_regulator_head, a), [c_1, c_2, c_3, c_4])
end


function constraint_on_off_valve_flow(wm::AbstractNCModel, n::Int, a::Int, q_max_reverse::Float64, q_min_forward::Float64)
    # Get flow and valve status variables.
    q, z = var(wm, n, :q_valve, a), var(wm, n, :z_valve, a)

    # If the valve is closed, flow must be zero.
    q_lb, q_ub = JuMP.lower_bound(q), JuMP.upper_bound(q)
    c_1 = JuMP.@constraint(wm.model, q >= q_lb * z)
    c_2 = JuMP.@constraint(wm.model, q <= q_ub * z)

    # Append the constraint array.
    append!(con(wm, n, :on_off_valve_flow, a), [c_1, c_2])
end


function constraint_on_off_valve_head(wm::AbstractNCModel, n::Int, a::Int, node_fr::Int, node_to::Int)
    # Get flow and valve status variables.
    q, z = var(wm, n, :q_valve, a), var(wm, n, :z_valve, a)

    # Get head variables for from and to nodes.
    h_i, h_j = var(wm, n, :h, node_fr), var(wm, n, :h, node_to)

    # When the valve is open, negative head loss is not possible.
    dh_lb = JuMP.lower_bound(h_i) - JuMP.upper_bound(h_j)
    c_1 = JuMP.@constraint(wm.model, h_i - h_j >= (1.0 - z) * dh_lb)

    # When the valve is open, positive head loss is not possible.
    dh_ub = JuMP.upper_bound(h_i) - JuMP.lower_bound(h_j)
    c_2 = JuMP.@constraint(wm.model, h_i - h_j <= (1.0 - z) * dh_ub)

    # Append the constraint array.
    append!(con(wm, n, :on_off_valve_head, a), [c_1, c_2])
end


function constraint_short_pipe_flow(wm::AbstractNCModel, n::Int, a::Int, q_max_reverse::Float64, q_min_forward::Float64)
    # By default, there are no constraints, here.
end


function constraint_short_pipe_head(wm::AbstractNCModel, n::Int, a::Int, node_fr::Int, node_to::Int)
    # Get head variables for from and to nodes.
    h_i, h_j = var(wm, n, :h, node_fr), var(wm, n, :h, node_to)

    # For short pipes, the heads at adjacent nodes are equal.
    c = JuMP.@constraint(wm.model, h_i - h_j == 0.0)

    # Append the constraint array.
    append!(con(wm, n, :short_pipe_head, a), [c])
end


function constraint_intermediate_directionality(
    wm::AbstractNCModel, n::Int, i::Int, pipe_fr::Array{Int64,1},
    pipe_to::Array{Int64,1}, des_pipe_fr::Array{Int64,1}, des_pipe_to::Array{Int64,1},
    pump_fr::Array{Int64,1}, pump_to::Array{Int64,1}, regulator_fr::Array{Int64,1},
    regulator_to::Array{Int64,1}, short_pipe_fr::Array{Int64,1},
    short_pipe_to::Array{Int64,1}, valve_fr::Array{Int64,1}, valve_to::Array{Int64,1})
    # For undirected formulations, there are no constraints, here.
end


function constraint_sink_directionality(
    wm::AbstractNCModel, n::Int, i::Int, pipe_fr::Array{Int64,1},
    pipe_to::Array{Int64,1}, des_pipe_fr::Array{Int64,1}, des_pipe_to::Array{Int64,1},
    pump_fr::Array{Int64,1}, pump_to::Array{Int64,1}, regulator_fr::Array{Int64,1},
    regulator_to::Array{Int64,1}, short_pipe_fr::Array{Int64,1},
    short_pipe_to::Array{Int64,1}, valve_fr::Array{Int64,1}, valve_to::Array{Int64,1})
    # For undirected formulations, there are no constraints, here.
end


function constraint_source_directionality(
    wm::AbstractNCModel, n::Int, i::Int, pipe_fr::Array{Int64,1},
    pipe_to::Array{Int64,1}, des_pipe_fr::Array{Int64,1}, des_pipe_to::Array{Int64,1},
    pump_fr::Array{Int64,1}, pump_to::Array{Int64,1}, regulator_fr::Array{Int64,1},
    regulator_to::Array{Int64,1}, short_pipe_fr::Array{Int64,1},
    short_pipe_to::Array{Int64,1}, valve_fr::Array{Int64,1}, valve_to::Array{Int64,1})
    # For undirected formulations, there are no constraints, here.
end


"Defines the objective for the owf problem is `NC` formulations."
function objective_owf_default(wm::AbstractNCModel)
    objective = zero(JuMP.QuadExpr)

    for (n, nw_ref) in nws(wm)
        for (a, pump) in nw_ref[:pump]
            # Ensure that the pump has an associated energy price.
            @assert haskey(pump, "energy_price")

            # Get pump flow and status variables.
            q, z = var(wm, n, :q_pump, a), var(wm, n, :z_pump, a)
            energy_qa = _calc_pump_energy_quadratic_approximation(wm, n, a, z)
            JuMP.add_to_expression!(objective, pump["energy_price"] * energy_qa(q))
        end
    end

    # Minimize the cost (in units of currency) required to operate pumps.
    return JuMP.@objective(wm.model, _MOI.MIN_SENSE, objective)
end
