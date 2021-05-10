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

function tyenv_eval(expr, env::Env)
	predefs = :(begin end)
	for (name, typ) in env
		if !(typ isa TypeVar)
			continue
		end
		push!(predefs.args, :($(name.name) = $typ))
	end
	push!(predefs.args, expr)
	return eval(predefs)
end

function toexpr(expr::Symbol)
	return expr
end
function toexpr(expr::CSTParser.EXPR)
	return Expr(expr)
end
