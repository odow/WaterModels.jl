function solve_des(network, model_constructor, optimizer; kwargs...)
    return solve_model(network, model_constructor, optimizer, build_des; kwargs...)
end

function build_des(wm::AbstractWaterModel)
    # Create head loss functions, if necessary.
    function_head_loss(wm)

    # Physical variables.
    variable_head(wm)
    variable_head_gain(wm)
    variable_flow(wm)
    variable_flow_des(wm)
    variable_volume(wm)

    # Indicator (status) variables.
    variable_check_valve_indicator(wm)
    variable_shutoff_valve_indicator(wm)
    variable_pressure_reducing_valve_indicator(wm)
    variable_pump_indicator(wm)

    # Component-specific variables.
    variable_pump_operation(wm)
    variable_reservoir(wm)
    variable_tank(wm)

    # Add the network design objective.
    objective_des(wm)

    for (a, pipe) in ref(wm, :pipe_fixed)
        constraint_pipe_head_loss(wm, a)
    end

    for (a, check_valve) in ref(wm, :check_valve)
        constraint_check_valve_head_loss(wm, a)
    end

    for (a, shutoff_valve) in ref(wm, :shutoff_valve)
        constraint_shutoff_valve_head_loss(wm, a)
    end

    for (a, pipe) in ref(wm, :pipe_des)
        constraint_pipe_head_loss_des(wm, a)
    end

    for a in ids(wm, :pressure_reducing_valve)
        constraint_prv_head_loss(wm, a)
    end

    for a in ids(wm, :pump)
        constraint_pump_head_gain(wm, a)
    end

    # Flow conservation at all nodes.
    for (i, node) in ref(wm, :node)
        constraint_flow_conservation(wm, i)
    end

    # Set source node hydraulic heads.
    for (i, reservoir) in ref(wm, :reservoir)
        constraint_source_head(wm, i)
        constraint_source_flow(wm, i)
    end

    for (i, junction) in ref(wm, :junction)
        # TODO: The conditional may be redundant, here.
        if junction["demand"] > 0.0
            constraint_sink_flow(wm, i)
        end
    end

    for i in ids(wm, :tank)
        # Link tank volume variables with tank head variables.
        constraint_link_volume(wm, i)

        # Set the initial tank volume.
        constraint_tank_state(wm, i)
    end

    # Add the energy conservation (primal-dual) constraint.
    constraint_energy_conservation(wm)
end
