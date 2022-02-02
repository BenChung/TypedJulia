MacroTools.isexpr(x::EXPR) = true
MacroTools.isexpr(x::EXPR, ts...) = x.head in ts

function MacroTools.rmlines(x::EXPR)
  # Do not strip the first argument to a macrocall, which is
  # required.
  if x.head == :macrocall && length(x.args) >= 2
    EXPR(x.head, [x.args[1], nothing, filter(x->!isline(x), x.args[3:end])...], x.trivia, x.fullspan, x.span, x.val, x.parent, x.meta)
  else
    EXPR(x.head, [filter(x->!isline(x), x.args)...], x.trivia, x.fullspan, x.span, x.val, x.parent, x.meta)
  end
end
MacroTools.walk(x::EXPR, inner, outer) = outer(EXPR(x.head, map(inner, x.args), x.trivia, x.fullspan, x.span, x.val, x.parent, x.meta))

function MacroTools.match_inner(pat::Expr, ex::EXPR, env)
  MacroTools.@trymatch MacroTools.match(pat.head, ex.head, env)
  pat, ex = MacroTools.rmlines(pat), MacroTools.rmlines(ex)
  sr = MacroTools.slurprange(pat.args)
  slurp = Any[]
  i = 1
  for p in pat.args
    i > length(ex.args) &&
      (MacroTools.isslurp(p) ? MacroTools.@trymatch(MacroTools.store!(env, MacroTools.bname(p), slurp)) : MacroTools.@nomatch(pat, ex))

    while MacroTools.inrange(i, sr, length(ex.args))
      push!(slurp, ex.args[i])
      i += 1
    end

    if MacroTools.isslurp(p)
      p ≠ :__ && MacroTools.@trymatch MacroTools.store!(env, MacroTools.bname(p), slurp)
    else
      MacroTools.@trymatch MacroTools.match(p, ex.args[i], env)
      i += 1
    end
  end
  i == length(ex.args)+1 || MacroTools.@nomatch(pat, ex)
  return env
end

function make_expr(cst::CSTParser.EXPR)
	if cst.head == :OPERATOR
		return Expr(Symbol(cst.val))
	else
		throw("Expected identifier at $cst")
	end
end

function MacroTools.match_inner(pat, ex::EXPR, env)
  return MacroTools.match_inner(pat, CSTParser.to_codeobject(ex), env)
end

function MacroTools.match_inner(pat::MacroTools.OrBind, ex::EXPR, env)
	env′ = MacroTools.trymatch(pat.pat1, ex)
	env′ == nothing ? MacroTools.match(pat.pat2, ex, env) : merge!(env, env′)
end

function MacroTools.normalise(ex::EXPR)
  ex = unblock(ex)
  isexpr(ex, :quotenode) && (ex = Expr(:quote, ex.args[1]))
  isexpr(ex, :inert) && (ex = Expr(:quote, ex.args[1]))
  isa(ex, QuoteNode) && (ex = Expr(:quote, ex.value))
  isexpr(ex, :kw) && (ex = Expr(:(=), ex.args...))
  return ex
end
