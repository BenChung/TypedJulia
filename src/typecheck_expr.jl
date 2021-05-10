function typecheck_getfield(expr, ctx::Env)
end

function typecheck_cond_clause(cond, body, ctx::Env)
	condty = typecheck_expr(cond, ctx)
	if !isstatictype(condty, Bool)
		throw("Non-boolean of type $condty used as condition")
	end
	return typecheck_expr(body, ctx)
end

function typecheck_if(expr, ctx::Env)
	restys = StaticType[]
	while expr.head == :if || expr.head == :elseif 
		push!(restys, typecheck_cond_clause(expr.args[1], expr.args[2], ctx)) # todo: something more clever with ctx
		if length(expr.args) > 2
			expr = expr.args[3]
		else 
			break
		end
	end
	return typemeet(restys)
end

function bind(ctx, vars, vals)
	if length(vals) != length(vars)
		throw("unequal number of values and variables at $vals and $vars")
	end
	#todo: deal with non-variable LHSes (e.g. x.field, x[property], etc)
	for (var, val) in zip(vars, vals)
		ctx[var] = val
	end
end

function typecheck_expr(expr, ctx::Env)
	if CSTParser.isbeginorblock(expr)
		last_type = BasicType{Nothing}()
		for iexp in expr.args
			last_type = typecheck_expr(iexp, ctx)
		end
		return last_type
	elseif CSTParser.isidentifier(expr)
		return lookup_symbol(Symbol(expr.val), ctx)
	elseif CSTParser.isoperator(expr)
		return lookup_symbol(Symbol(expr.val), ctx)
	elseif CSTParser.isstring(expr)
		return BasicType{String}();
	elseif CSTParser.isfloat(expr)
		return BasicType{Float64}()
	elseif CSTParser.isinteger(expr)
		return BasicType{Int}()
	elseif CSTParser.ischar(expr)
		return BasicType{Char}()
	elseif expr.head == :TRUE || expr.head == :FALSE
		return BasicType{Bool}()
	elseif expr.head == :vect
		return BasicType{Vector{canonize(typemeet(typecheck_expr.(expr.args, (ctx, ))))}}()
	elseif @capture(expr, rec_.var_)
		recty = typecheck_expr(rec, ctx)
		
	elseif CSTParser.isassignment(expr)
		lhs_match = @capture(expr.args[1], (vars__,) | var_)
		if !lhs_match
			throw("unhandled lhs $(expr)")
		end
		value = typecheck_expr(expr.args[2], ctx)
		if var == nothing 
			return bind(ctx, vars, destruct_tuple(value))
		else
			return bind(ctx, [var], [value])
		end
	elseif CSTParser.istuple(expr)
		return BasicType{Tuple{canonize.(typecheck_expr.(expr.args, (ctx, )))...}}()
	elseif expr.head == :if
		return typecheck_if(expr, ctx)
	elseif expr.head == :while
		typecheck_cond_clause(expr.args[1], expr.args[2], ctx)
		return BasicType{Nothing}()
	elseif @capture(expr, for ivars_ in coll_ body_ end) 
		lhs_match = @capture(ivars, (vars__,) | var_)
		if !lhs_match
			throw("wtf how did we get here")
		end
		rhs = typecheck_expr(coll, ctx)
		if vars == nothing
			bind(ctx, [var], [static_eltype(rhs)]) # the scoping on this is wrong
		else
			bind(ctx, vars, destruct_tuple(static_eltype(rhs)))
		end
		typecheck_expr(body, ctx)
		return BasicType{Nothing}()
	elseif expr.head == :return
		retty = typecheck_expr(expr.args[1], ctx)
		push!(ctx.returns, retty)
		return retty
	elseif CSTParser.iscall(expr)
		rec_typ = typecheck_expr(first(expr.args), ctx)
		arg_typs = typecheck_expr.(expr.args[2:end], (ctx,))
		mask = dyn_mask([rec_typ, arg_typs...])
		return dispatch_typed_direct(canonize(rec_typ), canonize.(arg_typs), mask)
	end
	throw("Unhandled expr form $expr")
end