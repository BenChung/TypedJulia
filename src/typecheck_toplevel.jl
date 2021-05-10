function build_mdef_env(definfo, base_env::Env)
	env = Env(base_env)
	for arg in splitwhere.(definfo[:whereparams])
		tv = TypeVar(toexpr(arg[2]))
		if !isnothing(arg[1])
			tv.lb = tyenv_eval(toexpr(arg[1]), env)
		end
		if !isnothing(arg[3])
			tv.ub = tyenv_eval(toexpr(arg[3]), env)
		end
		env[arg[2]] = BasicType{tv}()
	end
	for arg in MacroTools.splitarg.(definfo[:args])
		env[arg[1]] = BasicType{tyenv_eval(toexpr(arg[2]), env)}()
	end
	for arg in MacroTools.splitarg.(definfo[:kwargs])
		env[arg[1]] = BasicType{tyenv_eval(toexpr(arg[2]), env)}()
	end
	return env
end

function typecheck_mdef(expr::CSTParser.EXPR, env::Env)
	definfo = MacroTools.splitdef(expr)
	menv = build_mdef_env(definfo, env)
	return typecheck_expr(definfo[:body], menv)
end

function typecheck_toplevel(expr::CSTParser.EXPR, env=Env())
	if expr.head == :file || CSTParser.isbeginorblock(expr)
		lr = nothing
		for body_expr in expr.args
			lr = typecheck_toplevel(body_expr, env)
		end
		return lr
	end
	if CSTParser.defines_datatype(expr) || CSTParser.defines_function(expr) || CSTParser.defines_anon_function(expr)
		return typecheck_mdef(expr, env)
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