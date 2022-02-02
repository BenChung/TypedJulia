function build_mdef_env(definfo, base_env::Env, scope)
	env = Env(base_env)
	for arg in splitwhere.(definfo[:whereparams])
		tv = TypeVar(toexpr(arg[2]))
		if !isnothing(arg[1])
			tv.lb = tyenv_eval(toexpr(arg[1]), env, scope)
		end
		if !isnothing(arg[3])
			tv.ub = tyenv_eval(toexpr(arg[3]), env, scope)
		end
		@info "adding type var $tv to the environment lb $(tv.lb) ub $(tv.ub)"
		env[arg[2]] = BasicType(tv)
	end
	for arg in MacroTools.splitarg.(definfo[:args])
		if isnothing(arg[1]) continue end
		env[arg[1]] = BasicType(tyenv_eval(toexpr(arg[2]), env, scope))
	end
	for arg in MacroTools.splitarg.(definfo[:kwargs])
		env[arg[1]] = BasicType(tyenv_eval(toexpr(arg[2]), env, scope))
	end
	return env
end

function typecheck_mdef(expr::CSTParser.EXPR, env::Env)
	computed_scope = resolve_scope(expr, false)
	definfo = MacroTools.splitdef(expr)
	@debug "typechecking definition in scope $computed_scope"
	menv = build_mdef_env(definfo, env, computed_scope)
	return typecheck_expr(definfo[:body], menv)
end

function typecheck_toplevel(expr::CSTParser.EXPR, env=Env())
	if expr.head == :file || CSTParser.isbeginorblock(expr)
		lr = nothing
		for body_expr in expr.args
			try
			lr = typecheck_toplevel(body_expr, env)
			catch e
				if !(e isa HandledError)
					@error sprint(showerror, e)
					@error "had typecheck error $e with stacktrace $(stacktrace(catch_backtrace()))"
					error_text = sprint(showerror, e, catch_backtrace())
					body_expr.meta.error = TypeError(error_text)
				end
			end
		end
		return lr
	end
	if CSTParser.defines_function(expr) || CSTParser.defines_anon_function(expr)
		return typecheck_mdef(expr, env)
	elseif CSTParser.defines_datatype(expr)
		# skip it, since a datatype doesn't actually return a value per se
	elseif expr.head == :using || expr.head == :import
		add_import(expr)
		return nothing
	else
		return typecheck_expr(expr, env)
	end
end

function typecheck_file(filename)
	file_str = read(filename, String)
	parsed = CSTParser.parse(file_str, true)
	return typecheck_toplevel(parsed)
end
