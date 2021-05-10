module TypedJulia
using MacroTools, CSTParser
using CSTParser: EXPR

mutable struct Meta
    error
end

include("types.jl")
include("macrotools.jl")
include("env.jl")
include("utils.jl")
include("lookup.jl")
include("function_call.jl")
include("typecheck_toplevel.jl")
include("typecheck_expr.jl")

end # module
