abstract type StaticType end
struct BasicType <: StaticType
	type
end
struct DynamicType <: StaticType end
struct ModuleType <: StaticType
	mod::Module
end # represents module types, since Module itself doesn't tell us enough
struct SpecialFunction <: StaticType
	fn::Function
end

canonize(b::BasicType) = b.type
canonize(::DynamicType) = Any
canonize(::ModuleType) = Module
canonize(s::SpecialFunction) = typeof(s.fn)

spec_typeof(obj::Core.IntrinsicFunction) = SpecialFunction(obj)
spec_typeof(obj::Type) = BasicType(Type{obj})
spec_typeof(obj::Module) = ModuleType(obj)
spec_typeof(obj) = BasicType(typeof(obj))

destruct_tuple(t::BasicType) = map(x -> BasicType(x), t.type.parameters)
destruct_tuple(t) = throw("Cannot destruct a non-tuple $t")

isstatictype(b::BasicType, ::Type{V}) where V = b.type <: V
isstatictype(b::BasicType, ::Type{TypeVar}) = b.type isa TypeVar
isstatictype(s::StaticType, ::Type{T}) where T = canonize(s) <: T
isstatictype(::Any, ::Any) = false

typemeet(t1::StaticType, ts::Vararg{StaticType}) = typemeet(StaticType[t1, ts...])
typemeet(tys::Vector{T}) where T <: StaticType = BasicType(Base.typejoin(canonize.(tys)...))

static_eltype(ty::BasicType) = BasicType(eltype(ty.type))
