using Test
using TypedJulia
using CSTParser

@test TypedJulia.typecheck_expr(CSTParser.parse("(2,2)"), TypedJulia.Env()) isa TypedJulia.BasicType{Tuple{Int,Int}}
@test TypedJulia.typecheck_expr(CSTParser.parse("2"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("true"), TypedJulia.Env()) isa TypedJulia.BasicType{Bool}
@test TypedJulia.typecheck_expr(CSTParser.parse("false"), TypedJulia.Env()) isa TypedJulia.BasicType{Bool}
@test TypedJulia.typecheck_expr(CSTParser.parse("2+2"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("x = 2"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("begin x = 2; x end"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("begin x,y = 2,\"hello\"; x end"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("begin x,y = 2,\"hello\"; y end"), TypedJulia.Env()) isa TypedJulia.BasicType{String}
@test TypedJulia.typecheck_expr(CSTParser.parse("if true 3 end"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("if true 3 else 4 end"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("if 2==3 3 else 4 end"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("if 2==3 3 elseif false 8 else 4 end"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("if 2==3 3 elseif false 8 elseif false 8 else 4 end"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test_throws TypedJulia.UndefVarError TypedJulia.typecheck_expr(CSTParser.parse("begin if 2==3 x=3 else x=\"hi\" end; x end"), TypedJulia.Env()) isa TypedJulia.BasicType{Int}
@test TypedJulia.typecheck_expr(CSTParser.parse("begin x = 2; if 2==3 x=3.0 end; x end"), TypedJulia.Env()) isa TypedJulia.BasicType{Real}
@test TypedJulia.typecheck_expr(CSTParser.parse("begin x = 2; x = \"string\"; x end"), TypedJulia.Env()) isa TypedJulia.BasicType{Any}
@test TypedJulia.typecheck_expr(CSTParser.parse("while true 2 end"), TypedJulia.Env()) isa TypedJulia.BasicType{Nothing}
@test TypedJulia.typecheck_expr(CSTParser.parse("for x in [1,2,3] x+2 end"), TypedJulia.Env()) isa TypedJulia.BasicType{Nothing}
@test TypedJulia.typecheck_expr(CSTParser.parse("for (x,y) in [(1,3),(2,5),(3,3)] x+2 end"), TypedJulia.Env()) isa TypedJulia.BasicType{Nothing}