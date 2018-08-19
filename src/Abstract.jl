module Abstract
using MLStyle

Option{T} = Union{Some{T}, Nothing}


Expr = Any

@data Python begin
     # Expr

    Const{T}(value :: T)
    Symbol(name :: String)
    Call(func, args :: Vector, keywords :: Vector)
    Yield(value)
    YieldFrom(value)


    # Helper
    Arg(name::String, annotation :: Option{Expr})

    Args(args :: Vector{Arg},
         vararg :: Option{Arg},
         kwarg : Option{Arg},
         keyword_only_args :: Vector{Arg},
         defaults :: Vector{Expr},
         returns:Option{Expr})



    # Statement

    Defun(name::String, args :: Dict)

    NoReturnExpr(value)

end


end