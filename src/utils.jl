function seterror!(x::CSTParser.EXPR, e)
    if !hasmeta(x)
        x.meta = Meta()
    end
    x.meta.error = e
end


function splitwhere(expr)
	return @match expr begin
		x_ <: y_ => (nothing, x, y)
		x_ >: y_ => (y, x, nothing)
		y_ <: x_ <: z_ => (y, x, z)
	    x_ => (nothing, x, nothing)
	end
end

function tyenv_eval(expr, env::Env, scope_expr)
	predefs = :(begin end)
	for (name, typ) in env
		if !isstatictype(typ, TypeVar)
			continue
		end
		push!(predefs.args, :($(name.name) = $(typ.type)))
	end
	push!(predefs.args, expr)
	try
		return Base.eval(eval(scope_expr), predefs)
	catch e
		if e isa UndefVarError
			throw(TypeError("Missing variable $(e.var); scope expression: $(scope_expr)"))
		end
		rethrow(e)
	end
end

function toexpr(expr::Symbol)
	return expr
end
function toexpr(expr::CSTParser.EXPR)
	return CSTParser.to_codeobject(expr)
end
