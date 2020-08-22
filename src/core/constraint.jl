#########################################################################
# This file defines commonly-used constraints for water systems models. #
#########################################################################


"""
    constraint_reservoir_head(wm, n, i, head)
"""
function constraint_reservoir_head(wm::AbstractWaterModel, n::Int, i::Int, head::Float64)
    h = var(wm, n, :h, i)
    c = JuMP.@constraint(wm.model, h == head)
    con(wm, n, :reservoir_head)[i] = c
end


"""
    constraint_flow_conservation(
        wm, n, i, check_valve_fr, check_valve_to, pipe_fr, pipe_to, des_pipe_fr,
        des_pipe_to, pump_fr, pump_to, pressure_reducing_valve_fr,
        pressure_reducing_valve_to, shutoff_valve_fr, shutoff_valve_to, reservoirs, tanks,
        dispatachable_junctions, fixed_demand)
"""
function constraint_flow_conservation(
    wm::AbstractWaterModel, n::Int, i::Int, check_valve_fr::Array{Int64,1},
    check_valve_to::Array{Int64,1}, pipe_fr::Array{Int64,1}, pipe_to::Array{Int64,1},
    des_pipe_fr::Array{Int64,1}, des_pipe_to::Array{Int64,1}, pump_fr::Array{Int64,1},
    pump_to::Array{Int64,1}, pressure_reducing_valve_fr::Array{Int64,1},
    pressure_reducing_valve_to::Array{Int64,1}, shutoff_valve_fr::Array{Int64,1},
    shutoff_valve_to::Array{Int64,1}, reservoirs::Array{Int64,1}, tanks::Array{Int64,1},
    dispatchable_junctions::Array{Int64,1}, fixed_demand::Float64)
    # Collect flow variable references per component.
    q_check_valve = var(wm, n, :q_check_valve)
    q_pipe = var(wm, n, :q_pipe)
    q_des_pipe = var(wm, n, :q_des_pipe_sum)
    q_pump = var(wm, n, :q_pump)
    q_pressure_reducing_valve = var(wm, n, :q_pressure_reducing_valve)
    q_shutoff_valve = var(wm, n, :q_shutoff_valve)

    # Add the flow conservation constraint.
    c = JuMP.@constraint(wm.model, -
         sum(q_check_valve[a] for a in check_valve_fr) +
         sum(q_check_valve[a] for a in check_valve_to) -
         sum(q_pipe[a] for a in pipe_fr) + sum(q_pipe[a] for a in pipe_to) -
         sum(q_des_pipe[a] for a in des_pipe_fr) + sum(q_des_pipe[a] for a in des_pipe_to) -
         sum(q_pump[a] for a in pump_fr) + sum(q_pump[a] for a in pump_to) -
         sum(q_pressure_reducing_valve[a] for a in pressure_reducing_valve_fr) +
         sum(q_pressure_reducing_valve[a] for a in pressure_reducing_valve_to) -
         sum(q_shutoff_valve[a] for a in shutoff_valve_fr) +
         sum(q_shutoff_valve[a] for a in shutoff_valve_to) == -
         sum(var(wm, n, :qr, k) for k in reservoirs) -
         sum(var(wm, n, :qt, k) for k in tanks) +
         sum(var(wm, n, :demand, k) for k in dispatchable_junctions) + fixed_demand)

    con(wm, n, :flow_conservation)[i] = c
end


function constraint_tank_state_initial(wm::AbstractWaterModel, n::Int, i::Int, V_0::Float64)
    V = var(wm, n, :V, i)
    c = JuMP.@constraint(wm.model, V == V_0)
    con(wm, n, :tank_state)[i] = c
end


"""
    constraint_tank_state(wm, n_1, n_2, i, time_step)

Adds a constraint that integrates the volume of a tank forward in time. Here, `wm` is the
WaterModels object, `n_1` is the index of a subnetwork within a multinetwork, `n_2` is the
index of another subnetwork forward in time, relative to `n_1`, i is the index of the tank,
and time_step is the time step (in seconds) between networks `n_1` and `n_2`.
"""
function constraint_tank_state(wm::AbstractWaterModel, n_1::Int, n_2::Int, i::Int, time_step::Float64)
    qt = var(wm, n_1, :qt, i) # Tank outflow.
    V_1, V_2 = var(wm, n_1, :V, i), var(wm, n_2, :V, i)
    c = JuMP.@constraint(wm.model, V_1 - time_step * qt == V_2)
    con(wm, n_2, :tank_state)[i] = c
end


function constraint_recover_volume(wm::AbstractWaterModel, i::Int, n_1::Int, n_f::Int)
    _initialize_con_dict(wm, :recover_volume, nw=n_f)
    V_1, V_f = var(wm, n_1, :V, i), var(wm, n_f, :V, i)
    c = JuMP.@constraint(wm.model, V_f >= V_1)
    con(wm, n_f, :recover_volume)[i] = c
end
