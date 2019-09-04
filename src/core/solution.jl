""
function build_solution(wm::AbstractWaterModel, solve_time; solution_builder=solution_owf!)
    sol = init_solution(wm)
    data = Dict{String, Any}("name" => wm.data["name"])

    if InfrastructureModels.ismultinetwork(wm.data)
        sol["multinetwork"] = true
        sol_nws = sol["nw"] = Dict{String,Any}()
        data_nws = data["nw"] = Dict{String,Any}()

        for (n, nw_data) in wm.data["nw"]
            sol_nw = sol_nws[n] = Dict{String,Any}()
            wm.cnw = parse(Int, n)
            solution_builder(wm, sol_nw)
            data_nws[n] = Dict("name" => get(nw_data, "name", "anonymous"),
                               "link_count" => length(ref(wm, :links)),
                               "node_count" => length(ref(wm, :nodes)))
        end
    else
        solution_builder(wm, sol)
        data["link_count"] = length(ref(wm, :links))
        data["node_count"] = length(ref(wm, :nodes))
    end

    cpu = Sys.cpu_info()[1].model
    memory = string(Sys.total_memory() / 2^30, " GB")

    solution = Dict{String,Any}(
        "termination_status" => JuMP.termination_status(wm.model),
        "primal_status" => JuMP.primal_status(wm.model),
        "objective_value" => JuMP.objective_value(wm.model),
        "solve_time" => solve_time,
        "solution" => sol,
        "machine" => Dict("cpu" => cpu, "memory" => memory),
        "data" => data)

    wm.solution = solution

    return solution
end

""
function init_solution(wm::AbstractWaterModel)
    data_keys = ["per_unit"]
    return Dict{String,Any}(key => wm.data[key] for key in data_keys)
end

""
function get_solution(wm::AbstractWaterModel, sol::Dict{String, <:Any})
    add_pipe_flow_rate_setpoint(sol, wm)
    add_pump_flow_rate_setpoint(sol, wm)
    add_pump_status_setpoint(sol, wm)
    add_pipe_resistance_setpoint(sol, wm)
    add_node_head_setpoint(sol, wm)
    add_reservoir_setpoint(sol, wm)
end

function solution_owf!(wm::AbstractWaterModel, sol::Dict{String,<:Any})
    add_setpoint_pipe_flow!(sol, wm)
    add_setpoint_pump_flow!(sol, wm)
    #add_setpoint_pump_status!(sol, wm)
    add_setpoint_pipe_resistance!(sol, wm)
    add_setpoint_node_head!(sol, wm)
    #add_setpoint_reservoir!(sol, wm)
end

function add_pipe_flow_rate_setpoint(sol, wm::AbstractWaterModel)
    add_setpoint(sol, wm, "pipes", "q", :q)
end

function add_pump_flow_rate_setpoint(sol, wm::AbstractWaterModel)
    add_setpoint(sol, wm, "pumps", "q", :q)
end

function add_pump_status_setpoint(sol, wm::AbstractWaterModel)
    add_setpoint(sol, wm, "pumps", "x_pump", :x_pump)
end

function add_node_head_setpoint(sol, wm::AbstractWaterModel)
    add_setpoint(sol, wm, "nodes", "h", :h)
end

function add_node_head_setpoint(sol, wm::AbstractCNLPModel)
    add_dual_setpoint(sol, wm, "nodes", "h", :flow_conservation)
end

function add_reservoir_setpoint(sol, wm::AbstractWaterModel)
    add_setpoint(sol, wm, "reservoirs", "q_r", :q_r)
end

function add_tank_setpoint(sol, wm::AbstractWaterModel)
    add_setpoint(sol, wm, "reservoirs", "q_t", :q_t)
end

function add_pipe_resistance_setpoint(sol, wm::AbstractWaterModel)
    if InfrastructureModels.ismultinetwork(wm.data)
        data_dict = wm.data["nw"]["$(wm.cnw)"]["pipes"]
    else
        data_dict = wm.data["pipes"]
    end

    sol_dict = get(sol, "pipes", Dict{String, Any}())

    if length(data_dict) > 0
        sol["pipes"] = sol_dict
    end

    if :x_res in keys(var(wm))
        for (i, link) in data_dict
            a = link["index"]
            sol_item = sol_dict[i] = get(sol_dict, i, Dict{String, Any}())

            if a in keys(var(wm, :x_res))
                x_res, r_id = findmax(JuMP.value.(var(wm, :x_res, a)))
                sol_item["r"] = ref(wm, :resistance, a)[r_id]
            else
                x_res, r_id = findmin(ref(wm, :resistance, a))
                sol_item["r"] = ref(wm, :resistance, a)[r_id]
            end
        end
    else
        for (i, link) in data_dict
            a = link["index"]
            sol_item = sol_dict[i] = get(sol_dict, i, Dict{String, Any}())
            x_res, r_id = findmin(ref(wm, :resistance, a))
            sol_item["r"] = ref(wm, :resistance, a)[r_id]
        end
    end
end

""
function add_setpoint_node_head!(sol, wm::AbstractWaterModel)
    add_setpoint!(sol, wm, "nodes", "h", :h,
        status_name=wm_component_status["nodes"],
        inactive_status_value=wm_component_status_inactive["nodes"])
end

function add_setpoint_node_head!(sol, wm::AbstractCNLPModel)
    add_dual!(sol, wm, "nodes", "h", :flow_conservation,
        scale=(x, item) -> -x, status_name=wm_component_status["nodes"])
end

""
function add_setpoint_pipe_flow!(sol, wm::AbstractWaterModel)
    add_setpoint!(sol, wm, "pipes", "q", :q,
        status_name=wm_component_status["pipes"],
        inactive_status_value=wm_component_status_inactive["pipes"])
end

""
function add_setpoint_pump_flow!(sol, wm::AbstractWaterModel)
    add_setpoint!(sol, wm, "pumps", "q", :q,
        status_name=wm_component_status["pumps"],
        inactive_status_value=wm_component_status_inactive["pumps"])
end

function add_setpoint_pipe_resistance!(sol, wm::AbstractWaterModel)
    if InfrastructureModels.ismultinetwork(wm.data)
        data_dict = wm.data["nw"]["$(wm.cnw)"]["pipes"]
    else
        data_dict = wm.data["pipes"]
    end

    sol_dict = get(sol, "pipes", Dict{String, Any}())

    if length(data_dict) > 0
        sol["pipes"] = sol_dict
    end

    if :x_res in keys(var(wm))
        for (i, link) in data_dict
            a = link["index"]
            sol_item = sol_dict[i] = get(sol_dict, i, Dict{String, Any}())

            if a in keys(var(wm, :x_res))
                x_res, r_id = findmax(JuMP.value.(var(wm, :x_res, a)))
                sol_item["r"] = ref(wm, :resistance, a)[r_id]
            else
                x_res, r_id = findmin(ref(wm, :resistance, a))
                sol_item["r"] = ref(wm, :resistance, a)[r_id]
            end
        end
    else
        for (i, link) in data_dict
            a = link["index"]
            sol_item = sol_dict[i] = get(sol_dict, i, Dict{String, Any}())
            x_res, r_id = findmin(ref(wm, :resistance, a))
            sol_item["r"] = ref(wm, :resistance, a)[r_id]
        end
    end
end

"adds values based on JuMP variables"
function add_setpoint!(
    sol,
    wm::AbstractWaterModel,
    dict_name,
    param_name,
    variable_symbol;
    index_name = "index",
    default_value = (item) -> NaN,
    scale = (x,item) -> x,
    var_key = (idx,item) -> idx,
    sol_dict = get(sol, dict_name, Dict{String,Any}()),
    status_name = "status",
    inactive_status_value = 0)

    has_variable_symbol = haskey(var(wm, wm.cnw), variable_symbol)

    variables = []
    if has_variable_symbol
        variables = var(wm, wm.cnw, variable_symbol)
    end

    if !has_variable_symbol || (!isa(variables, JuMP.VariableRef) && length(variables) == 0)
        add_setpoint_fixed!(sol, wm, dict_name, param_name; index_name=index_name, default_value=default_value)
        return
    end

    if InfrastructureModels.ismultinetwork(wm.data)
        data_dict = wm.data["nw"]["$(wm.cnw)"][dict_name]
    else
        data_dict = wm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    for (i,item) in data_dict
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item[param_name] = default_value(item)

        if item[status_name] != inactive_status_value
            var_id = var_key(idx, item)
            variables = var(wm, wm.cnw, variable_symbol)
            sol_item[param_name] = scale(JuMP.value(variables[var_id]), item)
        end
    end
end

"""
adds setpoint values based on a given default_value function.
this significantly improves performance in models where values are not defined
"""
function add_setpoint_fixed!(
    sol,
    wm::AbstractWaterModel,
    dict_name,
    param_name;
    index_name = "index",
    default_value = (item) -> NaN,
    sol_dict = get(sol, dict_name, Dict{String,Any}()))

    if InfrastructureModels.ismultinetwork(wm.data)
        data_dict = wm.data["nw"]["$(wm.cnw)"][dict_name]
    else
        data_dict = wm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    for (i,item) in data_dict
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item[param_name] = default_value(item)
    end
end

"""
    function add_dual!(
        sol::AbstractDict,
        wm::AbstractWaterModel,
        dict_name::AbstractString,
        param_name::AbstractString,
        con_symbol::Symbol;
        index_name::AbstractString = "index",
        default_value::Function = (item) -> NaN,
        scale::Function = (x,item) -> x,
        con_key::Function = (idx,item) -> idx,
    )
This function takes care of adding the values of dual variables to the solution Dict.
# Arguments
- `sol::AbstractDict`: The dict where the desired final details of the solution are stored;
- `wm::AbstractWaterModel`: The WaterModel which has been considered;
- `dict_name::AbstractString`: The particular class of items for the solution (e.g. branch, bus);
- `param_name::AbstractString`: The name associated to the dual variable;
- `con_symbol::Symbol`: the Symbol attached to the class of constraints;
- `index_name::AbstractString = "index"`: ;
- `default_value::Function = (item) -> NaN`: a function that assign to each item a default value, for missing data;
- `scale::Function = (x,item) -> x`: a function to rescale the values of the dual variables, if needed;
- `con_key::Function = (idx,item) -> idx`: a method to extract the actual dual variables.
- `status_name::AbstractString: the status field of the given component type`
- `inactive_status_value::Any: the value of the status field indicating an inactive component`
"""
function add_dual!(
    sol::AbstractDict,
    wm::AbstractWaterModel,
    dict_name::AbstractString,
    param_name::AbstractString,
    con_symbol::Symbol;
    index_name::AbstractString = "index",
    default_value::Function = (item) -> NaN,
    scale::Function = (x, item) -> x,
    con_key::Function = (idx, item) -> idx,
    status_name = "status",
    inactive_status_value = 0)
    sol_dict = get(sol, dict_name, Dict{String,Any}())
    constraints = []
    has_con_symbol = haskey(con(wm, wm.cnw), con_symbol)

    if has_con_symbol
        constraints = con(wm, wm.cnw, con_symbol)
    end

    if !has_con_symbol || (!isa(constraints, JuMP.ConstraintRef) && length(constraints) == 0)
        add_dual_fixed!(sol, wm, dict_name, param_name; index_name=index_name, default_value=default_value)
        return
    end

    if ismultinetwork(wm)
        data_dict = wm.data["nw"]["$(wm.cnw)"][dict_name]
    else
        data_dict = wm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    for (i, item) in data_dict
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item[param_name] = default_value(item)

        if item[status_name] != inactive_status_value
            con_id = con_key(idx, item)
            constraints = con(wm, wm.cnw, con_symbol)
            sol_item[param_name] = scale(JuMP.dual(constraints[con_id]), item)
        end
    end
end

function add_dual_fixed!(
    sol::AbstractDict,
    wm::AbstractWaterModel,
    dict_name::AbstractString,
    param_name::AbstractString;
    index_name::AbstractString = "index",
    default_value::Function = (item) -> NaN)
    sol_dict = get(sol, dict_name, Dict{String,Any}())
    if ismultinetwork(wm)
        data_dict = wm.data["nw"]["$(wm.cnw)"][dict_name]
    else
        data_dict = wm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    for (i,item) in data_dict
        idx = Int(item[index_name])
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String,Any}())
        sol_item[param_name] = default_value(item)
        sol_item[param_name] = sol_item[param_name][1]
    end
end

"adds values based on JuMP variables"
function add_setpoint(sol::Dict{String, <:Any}, wm::AbstractWaterModel,
                      dict_name::String, param_name::String,
                      variable_symbol::Symbol; index_name::String="index",
                      default_value=(item) -> NaN, scale=(x, item) -> x,
                      extract_var=(var, idx, item) -> var[idx],
                      sol_dict=get(sol, dict_name, Dict{String, Any}()))
    if InfrastructureModels.ismultinetwork(wm.data)
        data_dict = wm.data["nw"]["$(wm.cnw)"][dict_name]
    else
        data_dict = wm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    for (i, item) in data_dict
        idx = item[index_name]
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String, Any}())
        sol_item[param_name] = default_value(item)

        try
            variable = extract_var(var(wm, wm.cnw, variable_symbol), idx, item)
            sol_item[param_name] = scale(JuMP.value(variable), item)
        catch
        end

        sol_item[param_name] = sol_item[param_name][1]
    end
end

"adds dual values based on JuMP constraints"
function add_dual_setpoint(sol::Dict{String, <:Any}, wm::AbstractWaterModel,
                           dict_name::String, param_name::String,
                           constraint_symbol::Symbol; index_name::String="index",
                           default_value=(item) -> NaN, scale=(x, item) -> x,
                           extract_con=(con, idx, item) -> con[idx],
                           sol_dict=get(sol, dict_name, Dict{String, Any}()))
    if InfrastructureModels.ismultinetwork(wm.data)
        data_dict = wm.data["nw"]["$(wm.cnw)"][dict_name]
    else
        data_dict = wm.data[dict_name]
    end

    if length(data_dict) > 0
        sol[dict_name] = sol_dict
    end

    for (i, item) in data_dict
        idx = item[index_name]
        sol_item = sol_dict[i] = get(sol_dict, i, Dict{String, Any}())
        sol_item[param_name] = default_value(item)

        try
            constraint = extract_con(con(wm, wm.cnw, constraint_symbol), idx, item)
            sol_item[param_name] = -scale(JuMP.dual(constraint), item)
        catch
        end

        sol_item[param_name] = sol_item[param_name][1]
    end
end
