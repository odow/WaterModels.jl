module WaterModels
import InfrastructureModels
import InfrastructureModels:
    ids, ref, var, con, sol, nw_ids, nws, optimize_model!, @im_fields
const _IM = InfrastructureModels

import Interpolations
import JSON
import JuMP
import LsqFit
import Memento

import MathOptInterface
const _MOI = MathOptInterface

# Create our module-level logger (this will get precompiled).
const _LOGGER = Memento.getlogger(@__MODULE__)

# Register the module-level logger at runtime so users can access the logger via
# `getlogger(WaterModels)` NOTE: If this line is not included, then the precompiled
# `WaterModels._LOGGER` will not be registered at runtime.
__init__() = Memento.register(_LOGGER)

"Suppresses information and warning messages output by WaterModels. For
more fine-grained control, use the Memento package."
function silence()
    msg = "Suppressing information and warning messages for the rest of this session. " *
        "Use the Memento package for more fine-grained control of logging."
    Memento.info(_LOGGER, msg)
    Memento.setlevel!(Memento.getlogger(InfrastructureModels), "error")
    Memento.setlevel!(Memento.getlogger(WaterModels), "error")
end

"Allows the user to set the logging level without the need to add Memento."
function logger_config!(level)
    Memento.config!(Memento.getlogger("WaterModels"), level)
end

const _wm_global_keys = Set(["time_series", "per_unit", "head_loss", "viscosity"])

include("io/common.jl")
include("io/epanet.jl")

include("core/base.jl")
include("core/constants.jl")

include("core/node.jl")
include("core/demand.jl")
include("core/reservoir.jl")
include("core/tank.jl")

include("core/pipe.jl")
include("core/pump.jl")
include("core/regulator.jl")
include("core/short_pipe.jl")
include("core/valve.jl")

include("core/data.jl")
include("core/ref.jl")
include("core/types.jl")
include("core/function.jl")
include("core/variable.jl")

include("core/constraint.jl")
include("core/constraint_template.jl")
include("core/objective.jl")

include("form/nc.jl")
include("form/ncd.jl")
include("form/crd.jl")
include("form/la.jl")
include("form/outer_approximation.jl")
include("form/pwlrd.jl")
include("form/lrd.jl")

include("prob/wf.jl")
include("prob/owf.jl")
include("prob/des.jl")

include("util/relax.jl")
include("util/variable_index.jl")
include("util/pairwise_cuts.jl")
include("util/pump_volume_cuts.jl")
include("util/obbt.jl")

include("core/export.jl")
end
