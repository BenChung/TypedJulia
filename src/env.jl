struct Binding
	name::Symbol
	source::Union{EXPR, Nothing}
end

Base.:(==)(b1::Binding, b2::Binding) = b1.name == b2.name
Base.hash(b::Binding) = hash(b.name)

mutable struct Env
	typing::Base.ImmutableDict{Binding, StaticType}
	returns::Vector{Any}
	Env() = new(Base.ImmutableDict{Binding, StaticType}(), Any[])
	Env(e::Env) = new(e.typing, Any[])
end

Base.setindex!(e::Env, v::Any, b::EXPR) = setindex!(e, v, Binding(Expr(b), b))
function Base.setindex!(e::Env, v::Any, b::Binding)
	if haskey(e.typing, b)
		e.typing = Base.ImmutableDict(e.typing, b=>typemeet(e.typing[b], v))
	else
		e.typing = Base.ImmutableDict(e.typing, b=>v)
	end
end

function Base.getindex(e::Env, s::Symbol)
	return e.typing[Binding(s, nothing)]
end

function Base.haskey(e::Env, b::Binding)
	return haskey(e.typing, b)
end
Base.haskey(e::Env, s::Symbol) = haskey(e, Binding(s, nothing))

function updatefrom(tgt::Env, from::Env)
	for (binding, typ) in from
		if haskey(tgt, binding)
			tgt[binding] = typ
		end
	end
	# todo: more logic here
	copyto!(tgt.returns, from.returns)
end

struct Env_IterState{T}
	dict_iterstate::T
end

function Base.iterate(e::Env)
	inner_res = iterate(e.typing)
	if isnothing(inner_res)
		return nothing
	end
	item, internal_state = inner_res
	return (item, Env_IterState(internal_state))
end

function Base.iterate(e::Env, state::Env_IterState)
	inner_res = iterate(e.typing, state.dict_iterstate)
	if isnothing(inner_res)
		return nothing
	end
	item, internal_state = inner_res
	return (item, Env_IterState(internal_state))
end

Base.length(e::Env) = length(e.typing)

Base.eltype(::Type{Env}) = eltype(e.typing)
