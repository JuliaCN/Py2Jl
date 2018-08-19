module ASTGen

using MLStyle


function to_ast(filename, python :: Dict)


    @def apply begin
    (num :: Number)  => num
    (str :: String)  => str
    (nil :: Nothing) => nil

    Dict(:class => "Module", :name => name, :body => body) =>
        # What does the first index of ast of `module` mean?
        Expr(:module, true, map(apply, body)...)


    Dict(:class   => fn_ty_name,
         :args    =>
             Dict(:vararg      => vararg,
                  :kwonlyargs  => kwonlyargs,
                  :kw_defaults => kw_defaults,
                  :kwarg       => kwarg,
                  :lineno      => lineno, :colno => colno),
         :body = body) in fn_ast =>
         begin
                if kwarg === nothing && isempty(kwonlyargs)
                   if is_empty(kw_defaults) && is_empty(defaults)
                        args = map(apply, args)
                        block = apply(body)
                        if fn_ty_name == "Lambda"
                            Expr(:function, Expr(:tuple, args...), Expr(:block, body))
                        else

                            decorator_list = fn_ast[:decorator_list]
                            fn_name = Symbol(fn_ast[:name])
                            init = Expr(:function, Expr(:call, fn_name, args...), Expr(:block, body))
                            reduce(decorator_list, init=init) do last, decorator
                                Expr(:(=), fn_name, Expr(:let, Expr(:block), Expr(:call, apply(decorator), last)))
                            end

                        end
                   else
                        @error "not impl yet"
                   end
                else
                    @error "not impl yet"
                end
         end

    Dict(:class => "FunctionDef",
         :name => name,
         :args = args,
         :body = body,
         :decorator_list => decorator_list,
         :returns => returns) =>
                1



    end

    apply(python)

end


end