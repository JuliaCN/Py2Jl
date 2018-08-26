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

    Dict(:class => "Module", :body => body) =>
        # What does the first index of ast of `module` mean?
        Expr(:module, true, Symbol(filename), map(apply, body)...)


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
             # ant `iter` in Julia like that of Python?
             # I want to create a consumable generator of a iterable one.
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

    Dict(:class => "Try", :body => body, :handlers => handlers,:orelse => orelse, :finalbody => finalbody) =>
        if !isempty(finalbody) || !isempty(orelse)
            @not_implemented_yet
        else
            ret = Expr(:try, gather <| map(apply, body))
            if isempty(handlers)
                return ret
            end
            args = ret.args
            push!(args, :except)

            init = call(throw, (:except, ))
            foldr(handlers) do handler, last
                @match handler begin
                    Dict(:type => exc, :name=>nothing, :body=>body){(name=:except; true)} |
                    Dict(:type => exc, :name=>name,    :body=>body) =>
                    quote
                        if except isa $(apply(exc))
                            $name = except
                            $(map(apply, body)...)
                        else
                            $last
                        end
                    end

                    _ => @error "Unknown python ast."
                end
            end |> it -> push!(args, it)
            ret
        end

    Dict(:class => "Raise", :exc => nothing, :cause => nothing)   => call(throw, ())

    Dict(:class => "Raise", :exc => exc, :cause => nothing) => call(throw, (apply(exc), ))

    Dict(:class => "Raise", :exc => _, :cause => _) => @not_implemented_yet

    Dict(:class => "Import") => @not_implemented_yet

    Dict(:class => "ImportFrom") => @not_implemented_yet

    Dict(:class => "Global", :names => names) => Expr(:global, map(Symbol, names))

    Dict(:class => "Pass") => nothing

    Dict(:class => "Break") => break!()

    Dict(:class => "Continue") => continue!()

    Dict(:class => "If", :test => test, :body=body, :orelse => orelse) =>
        Expr(:if, apply(test), gather <| map(apply, body), gather <| map(apply, orelse)) |>
        ret_nil
    Dict(:class => "Expr", :value => value) => apply(value) |> ret_nil

    Dict(:class => "BinOp", :op => op, :left => left, :right => right) =>
       @match op[:class] begin
           # TODO, binary operator in Python cannot be mapped to Julia directly.
           # We should implement Python.(+), Python.(-)...
           "Add"     => (+)
           "Sub"     => (-)
           "Mult"    => (.*)
           "Div"     => (./)
           "MatMult" => (*)
           "Mod"     => (%)
           "Pow"     => (^)
           "LShift"  => (<<)
           "RShift"  => (>>)
           "BitOr"   => (|)
           "BitXor"  => xor
           "BitAnd"  => (&)
           "FloorDiv"=> floor ∘ (/)
       end |> it -> call(it, apply(left), apply(right))
    end

    apply(python)

end


end
