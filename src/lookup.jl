function add_import(expr)
end

function lookup_symbol(symbol, env::Env)
	if haskey(env, symbol)
		return env[symbol]
	end
	return spec_typeof(eval(symbol))
	# todo: look up in the code module what the binding is
end