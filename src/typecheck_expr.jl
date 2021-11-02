function typecheck_getfield(rec, var, ctx::Env)
	recty = typecheck_expr(rec, ctx)
	if var isa Symbol && recty isa BasicType
		return fieldtype(canonize(recty), var)
	end
	return BasicType(Any)
end

function ensure_typed_meta(expr::EXPR)
	if isnothing(expr.meta)
		expr.meta = Meta()
	elseif expr.meta isa StaticLint.Meta
		expr.meta = Meta(expr.meta)
	end
end

function typecheck_cond_clause(cond, body, ctx::Env)
	bodyctx = Env(ctx)
	condty = typecheck_expr(cond, bodyctx)
	if !isstatictype(condty, Bool)
		throw("Non-boolean of type $condty used as condition")
	end
	res = typecheck_expr(body, bodyctx)
	updatefrom(ctx, bodyctx)
	return res
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
		ensure_typed_meta(var)
		var.meta.type = val
	end
end

function typecheck_expr(expr, ctx::Env)
	try
		ensure_typed_meta(expr)
		res = typecheck_expr_(expr, ctx)
		expr.meta.type = res
		return res
	catch e
		if !(e isa HandledError)
			@error "had typecheck error $e with stacktrace $(stacktrace(catch_backtrace()))"
			expr.meta.error = TypeError(sprint(showerror, e))
			#@info "with environment $ctx"
			#@error "In expression $(Expr(expr)) had error"
			rethrow(HandledError(e))
		else
			rethrow(e)
		end
	end
end

function typecheck_expr_(expr, ctx::Env)
	if CSTParser.isbeginorblock(expr)
		last_type = BasicType(Nothing)
		for iexp in expr.args
			last_type = typecheck_expr(iexp, ctx)
		end
		return last_type
	elseif CSTParser.isidentifier(expr)
		return lookup_symbol(expr, ctx)
	elseif CSTParser.isoperator(expr)
		return lookup_symbol(expr, ctx)
	elseif CSTParser.isstring(expr)
		return BasicType(String)
	elseif CSTParser.isfloat(expr)
		return BasicType(Float64)
	elseif CSTParser.isinteger(expr)
		return BasicType(Int)
	elseif CSTParser.ischar(expr)
		return BasicType(Char)
	elseif expr.head == :TRUE || expr.head == :FALSE
		return BasicType(Bool)
	elseif expr.head == :vect
		return BasicType(Vector{canonize(typemeet(typecheck_expr.(expr.args, (ctx, ))))})
	elseif @capture(expr, rec_.var_)
		return typecheck_getfield(rec, var, ctx)
	elseif CSTParser.isassignment(expr)
		lhs_match = @capture(expr.args[1], (vars__,) | var_)
		if !lhs_match
			throw("unhandled lhs $(expr)")
		end
		value = typecheck_expr(expr.args[2], ctx)
		if var == nothing
			bind(ctx, vars, destruct_tuple(value))
		else
			bind(ctx, [var], [value])
		end
		return value
	elseif CSTParser.istuple(expr)
		return BasicType(Tuple{canonize.(typecheck_expr.(expr.args, (ctx, )))...})
	elseif expr.head == :if
		return typecheck_if(expr, ctx)
	elseif expr.head == :while
		typecheck_cond_clause(expr.args[1], expr.args[2], ctx)
		return BasicType(Nothing)
	elseif @capture(expr, for ivars_ in coll_ body_ end)
		lhs_match = @capture(ivars, (vars__,) | var_)
		if !lhs_match
			throw("wtf how did we get here")
		end
		rhs = typecheck_expr(coll, ctx)
		iterctx = Env(ctx)
		if vars == nothing
			bind(iterctx, [var], [static_eltype(rhs)]) # the scoping on this is wrong
		else
			bind(iterctx, vars, destruct_tuple(static_eltype(rhs)))
		end
		typecheck_expr(body, iterctx)
		updatefrom(ctx, iterctx)
		return BasicType(Nothing)
	elseif expr.head == :return
		retty = typecheck_expr(expr.args[1], ctx)
		push!(ctx.returns, retty)
		return retty
	elseif CSTParser.iscall(expr)
		rec_typ = typecheck_expr(first(expr.args), ctx)
		arg_typs = typecheck_expr.(expr.args[2:end], (ctx,))
		mask = dyn_mask([rec_typ, arg_typs...])
		try
			return dispatch_typed_direct(canonize(rec_typ), canonize.(arg_typs), mask)
		catch e
			expr.meta.error = TypeError(string(e))
			@info "set error on $(Expr(expr))"
			throw(HandledError("dispatch failed"))
		end
	end
	throw("Unhandled expr form $(expr.head) is call?")
end
