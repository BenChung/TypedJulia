module TypedJulia
using StaticLint:scope_exports
using MacroTools, CSTParser, Revise
using CSTParser:EXPR
using StaticLint, SymbolServer

include("types.jl")


struct TypeError
    message::String
end
struct HandledError <: Exception
    inner
end

StaticLint.iserror(::TypeError) = true

mutable struct Meta
    binding::Union{Nothing,StaticLint.Binding}
    scope::Union{Nothing,StaticLint.Scope}
    ref::Union{Nothing,StaticLint.Binding,SymbolServer.SymStore}
    type::Union{Nothing,StaticType}
    error
end
Meta(m::StaticLint.Meta) = Meta(m.binding, m.scope, m.ref, nothing, m.error)
Meta() = Meta(nothing, nothing, nothing, nothing, nothing)

function Base.show(io::IO, m::Meta)
    m.binding !== nothing && show(io, m.binding)
    m.ref !== nothing && printstyled(io, " * ", color=:red)
    m.scope !== nothing && printstyled(io, " new scope", color=:green)
    m.type !== nothing && printstyled(io, " type ", color=:green)
    m.error !== nothing && printstyled(io, " lint ", color=:red)
end
StaticLint.hasmeta(x::EXPR) = x.meta isa Meta || x.meta isa StaticLint.Meta
StaticLint.hasbinding(m::Meta) = m.binding isa StaticLint.Binding
StaticLint.hasref(m::Meta) = m.ref !== nothing
StaticLint.hasscope(m::Meta) = m.scope isa StaticLint.Scope
StaticLint.scopeof(m::Meta) = m.scope
StaticLint.bindingof(m::Meta) = m.binding
StaticLint.haserror(m::Meta) = m.error !== nothing

include("macrotools.jl")
include("env.jl")
include("utils.jl")
include("lookup.jl")
include("function_call.jl")
include("typecheck_toplevel.jl")
include("typecheck_expr.jl")
include("interface.jl")

end # module
