function dyn_mask(fnty)::BitArray{1}
	mask = BitArray(undef, (length(fnty)))
	for (ind, arg) in enumerate(fnty)
		mask[ind] = if arg isa DynamicType 1 else 0 end
	end
	return mask
end

function mask_type(mask::BitArray{1}, typ)
	if typ isa DataType
		return Tuple{mask_array(mask, typ.parameters)...}
	elseif typ isa UnionAll
		return UnionAll(typ.var, mask_type(mask, typ.body))
	else
		throw(MaskException(typ))
	end
end

function mask_array(mask::BitArray{1}, arr)
	return [if ind <= length(mask) && mask[ind] Any else arg end for (ind, arg) in enumerate(arr)]
end

function dispatch_typed_direct(fn::Union{Function, DataType}, canonical_args, mask)
	#println(args)
	world = ccall(:jl_get_tls_world_age, UInt, ())
	interp = Core.Compiler.NativeInterpreter(world)
	if fn isa Core.IntrinsicFunction
		throw(IntrinsicPassedException(fn))
	elseif fn <: Core.Builtin # we can be assured it exists?
		rt = Core.Compiler.builtin_tfunction(interp, fn.instance, Any[canonical_args...], nothing)
		#println("invoking builtin $fn with arguments $(canonical_args...) to return $rt")
		if isa(rt, TypeVar)
			return BasicType(rt.ub)
		else
			return BasicType(Core.Compiler.widenconst(rt))
		end
	end
	if fn <: Function
		fn_rec = fn
	else
		fn_rec = fn # fn.parameters[1]
	end
	argtuple = Tuple{fn, canonical_args...}
	#println("Fetching method $fn_rec with signature $(canonical_args) with fn $fn fnty $(typeof(fn))")
	directly_callable = Base._methods_by_ftype(Tuple{fn_rec, canonical_args...}, -1, typemax(UInt64))
	if length(directly_callable) > 0 # there is a method that we can
		has_candidate = false
		rt = Union{}
		for mdef in directly_callable
			#println("is $argtuple <: $(mdef.method.sig)? $(argtuple <: mdef.method.sig)")
			if mask_type(mask, argtuple) <: mask_type(mask, mdef.method.sig)
				has_candidate = true
			end
			rty = Core.Compiler.typeinf_type(interp, mdef.method, mdef.spec_types, mdef.sparams)
			rt = Core.Compiler.tmerge(rty, rt)
			#println("Callable $((mdef::Core.MethodMatch).method.sig), returning $rty, acc rty $rt")
		end
		if has_candidate
			return BasicType(rt)
		end
		# todo: check if there's an interface declared for this type
	end

	output = """Invalid method call $fn_rec with args $canonical_args
		Searching for functions using signature $argtuple within $directly_callable; attempts:
		$(join(["$(mdef.method.sig); argtuple <: typ?: $(argtuple <: mdef.method.sig)" for mdef in directly_callable], "\n"))
		out of all methods
		$(methods(fn_rec.instance))
	"""
	throw(output)
end
