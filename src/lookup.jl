function add_import(expr)
end

function walk_scopes_to_reference(s::Nothing)
	return Any[]
end

# will return a path to the bound variable
function walk_scopes_to_reference(s::StaticLint.Scope)
	if s.expr.head == :file
		return Any[]
	elseif s.expr.head == :module
		return push!(walk_scopes_to_reference(s.parent), Expr(s.expr.args[2]))
	elseif s.expr.head == :function
		fninfo = MacroTools.splitdef(s.expr)
		return push!(walk_scopes_to_reference(s.parent), Expr(fninfo[:name]))
	elseif s.expr.head isa CSTParser.EXPR && CSTParser.isassignment(s.expr)
		return push!(walk_scopes_to_reference(s.parent), Expr(s.expr.meta.binding.name))
	elseif s.expr.head == :struct
		return push!(walk_scopes_to_reference(s.parent), Expr(s.expr.args[2]))
	end
	@debug "falling through on expr head $(s.expr.head)"
	return Any[]
end

function resolve_scope(src::EXPR, include_name=true)
	scopes = walk_scopes_to_reference(src.meta.scope)
	if !include_name && length(scopes) > 0
		@debug "pop scope"
		pop!(scopes)
	end
	out = reduce((prnt, chld) -> :($prnt.$chld), scopes; init=:TypecheckMain)
	@debug "walked scopes to $out with terminal expr $(src.meta.binding)"
	return out
end

resolve_varref(vr::Nothing) = :TypecheckMain
resolve_varref(vr::SymbolServer.VarRef) = :($(resolve_varref(vr.parent)).$(vr.name))

function resolve_scope(b::StaticLint.Binding)
	@debug "resolving scope from binding with value $(b.val) and name $(b.name)"
	return resolve_scope(b.val)
end
resolve_scope(m::SymbolServer.ModuleStore) = resolve_varref(m.name)
resolve_scope(dts::SymbolServer.DataTypeStore) = resolve_varref(dts.name.name)
resolve_scope(fs::SymbolServer.FunctionStore) = resolve_varref(fs.name)
resolve_scope(gs::SymbolServer.GenericStore) = resolve_varref(gs.name)

function lookup_symbol(expr::EXPR, env::Env)
	if !isnothing(expr.val)
		symbol = Symbol(expr.val)
		if haskey(env, symbol)
			return env[symbol]
		end
	end
	if !isnothing(expr.meta.ref)
		#=
		@info "module store type $(typeof(expr.meta.ref.val))"
		if expr.meta.ref.val isa SymbolServer.ModuleStore
			function print_varref(vr)
				return if isnothing(vr) "Main" else "$(print_varref(vr.parent)).$(vr.name)" end
			end
			@info "module store name $(print_varref(expr.meta.ref.val.name))"
			@info "module store value $(typeof(expr.meta.ref.val[Symbol(expr.val)]))"
		end =#
		bound = resolve_scope(expr.meta.ref)
		@debug "resolved binding $bound; looking up $(expr.val) with type $(typeof(expr.meta.ref))"
		return spec_typeof(eval(bound))
	end
	return lookup_symbol(Symbol(expr.val), env)
end


function lookup_symbol(symbol::Symbol, env::Env)
	if haskey(env, symbol)
		return env[symbol]
	end
	return spec_typeof(TypecheckMain.eval(symbol))
end
