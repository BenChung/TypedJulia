abstract type StaticType end
struct BasicType{T} <: StaticType end
struct DynamicType <: StaticType end
struct ModuleType <: StaticType
	mod::Module
end # represents module types, since Module itself doesn't tell us enough
struct SpecialFunction <: StaticType
	fn::Function
end

canonize(::BasicType{T}) where T = T::Type
canonize(::DynamicType) = Any
canonize(::ModuleType) = Module
canonize(s::SpecialFunction) = typeof(s.fn)

spec_typeof(obj::Core.IntrinsicFunction) = SpecialFunction(obj)
spec_typeof(obj::Type) = BasicType{Type{obj}}()
spec_typeof(obj::Module) = ModuleType(obj)
spec_typeof(obj) = BasicType{typeof(obj)}()

destruct_tuple(t::BasicType{T}) where T <: Tuple = map(x->BasicType{x}(), T.parameters)
destruct_tuple(t) = throw("Cannot destruct a non-tuple $t")

isstatictype(::BasicType{T}, ::Type{V}) where {T,V <: T} = true
isstatictype(s::StaticType, ::Type{T}) where T = canonize(s) <: T
isstatictype(::Any, ::Any) = false

typemeet(t1::StaticType, ts::Vararg{StaticType}) = typemeet(StaticType[t1, ts...])
typemeet(tys::Vector{T}) where T<:StaticType = BasicType{Base.typejoin(canonize.(tys)...)}()

static_eltype(ty::BasicType{T}) where T = BasicType{eltype(T)}()