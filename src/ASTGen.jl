module ASTGen

using MLStyle

macro not_implemented_yet()
    @error "not_implemented_yet"
end

function ret_nil(node)
    Expr(:block, node, nothing)
end

function annotate(sym, ty)
    Expr(:(::), sym, ty)
end

function assign(target, value)
    Expr(:(=), target, value)
end

function (<|)(f, arg)
    f(arg)
end

function gather(args)
    Expr(:block, args...)
end

function call(fn, args)
    Expr(:call, fn, args...)
end

function as_global(names)
    Expr(:global, names...)
end

function break!()
    Expr(:break)
end

function continue!()
    Expr(:continue)
end

function to_ast(filename, python :: Dict)

    @def apply begin

    (num :: Number) => num
    (str :: String) => str
    (nil :: Nothing) => nil

    Dict(:class => "Module", :name => name, :body => body) =>
        # What does the first index of ast of `module` mean?
        Expr(:module, true, map(apply, body)...)


    Dict(:class => fn_ty_name,
         :args =>
             Dict(:vararg => vararg,
                  :kwonlyargs => kwonlyargs,
                  :kw_defaults => kw_defaults,
                  :kwarg => kwarg,
                  :lineno => lineno, :colno => colno),
         :body = body) in fn_ast =>
         begin
            if kwarg === nothing && isempty(kwonlyargs)
               if is_empty(kw_defaults) && is_empty(defaults)

                    args = map(apply, args)
                    block = gather <| map(apply, body)

                    if fn_ty_name == "Lambda"
                        Expr(:function, Expr(:tuple, args...), Expr(:block, body))
                    else
                        decorator_list = fn_ast[:decorator_list]
                        fn_name = Symbol(fn_ast[:name])
                        init = Expr(:function, Expr(:call, fn_name, args...), Expr(:block, body))
                        reduce(decorator_list, init=init) do last, decorator
                            Expr(:(=), fn_name, Expr(:let, Expr(:block), Expr(:call, apply(decorator), last)))
                        end |>
                        ret_nil
                    end
               else
                    @not_implemented_yet
               end
            else
                @not_implemented_yet
            end
         end

    Dict(:class => "Assign",
         :targets => targets,
         :value => value) =>

         reduce(targets, init = apply(value)) do last, target
            Expr(:(=), target, last)
         end |> ret_nil

    Dict(:class => "AugAssign",
         :target => target,
         :op => op,
         :value => value) =>
         @not_implemented_yet

    Dict(:class => "AnnAssign",
         :target => target,
         :annotation => annotation,
         :value => value) =>
         annotate(apply(target), apply(annotation)) |>
         target -> assign(target, value)            |>
         ret_nil

    Dict(:class => "For",
         :target => target,
         :iter => iter,
         :body => body,
         :or_else => or_else) =>
         if isempty(or_else)
            Expr(:for,
                 assign(apply(target), apply(iter)),
                 gather <| map(apply, body))
         else
            # a efficient implementation of `for...else...` is necessary.
            @not_implemented_yet
         end

    Dict(:class => "While",
         :test  => test,
         :body => body,
         :or_else => or_else) =>
         if isempty(or_else)
            Expr(:while,
                 apply(test),
                 gather <| map(apply, body))
         else
            @not_implemented_yet
         end

    Dict(:class => "With") => @not_implemented_yet

    Dict(:class => "ClassDef") => @not_implemented_yet

    Dict(:class => "Raise")   => @not_implemented_yet

    Dict(:class => "Import") => @not_implemented_yet

    Dict(:class => "ImportFrom") => @not_implemented_yet

    Dict(:class => "Global",
         :names = names) => as_global(map(apply, names))
    Dict(:class => "Pass") => nothing

    Dict(:class => "Break") => break!()

    Dict(:class => "Continue") => continue!()


    end



    apply(python)

end


end