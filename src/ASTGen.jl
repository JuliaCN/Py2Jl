module ASTGen
export to_ast
using MLStyle
using JSON

@inline function ID(x)
    x
end

compat_32842 =
    @static let  _v_mlstyle = begin
                        import Pkg
                        Pkg.installed()["MLStyle"]
                    end
                _v_mlstyle < v"0.3.1"
            end ?
        function _compat(ast)
            @match ast begin
                Expr(hd, tl...) => Expr(hd, map(_compat, tl)...)
                s::String       => :(ID($s))
                a               => a
            end
        end :
        function _no_compat(ast)
            ast
        end


macro compat_32842(ast)
    compat_32842(ast) |> esc
end

count = 0

IS_BREAK = Symbol("____Py2Jl____UNSAFE_MANGLE_IS_BREAK")
MANGLE_BASE = Symbol("____Py2Jl____UNSAFE_MANGLE_TMP")

mangle() = begin
    global count
    let name = Symbol(MANGLE_BASE, string(count))
        count = count + 1
        name
    end
end


module Extension
    using MLStyle
    using MLStyle.Infras
    using MLStyle.MatchCore
    struct Record end

    ASTGen = parentmodule(Extension)

    def_app_pattern(Extension,
        predicate = (hd_obj, args) -> hd_obj === Record,
        rewrite = (tag, hd_obj, args, mod) ->
        let
            args = ((arg isa Symbol ?
                    let key = QuoteNode(arg)
                        :($key => $arg)
                    end : arg)
                    for arg in args)
            pat = :(Dict($(args...)))
            mk_pattern(tag, pat, mod)
        end,
        qualifiers = Set([(_, u) -> u === ASTGen])
    )

    def_app_pattern(Extension,
        predicate = (hd_obj, args) -> hd_obj == ASTGen.ID,
        rewrite = (tag, hd_obj, args, mod) ->
        let str = args[1], pat = :(&$str)
            mk_pattern(tag, pat, mod)
        end,
        qualifiers = Set([(_, u) -> u === ASTGen])
    )
end

using .Extension: Record

macro not_implemented_yet()
    :(throw("notimplemented yet"))
end

# start compat_32842
@compat_32842 begin


empty_block = Expr(:block)

function ret_nil(node)
    Expr(:block, node, nothing)
end

"""
Cannot generate python annotations for
the semantics is not the same as Julia's annoations.
"""
function annotate(sym, ty)
    @not_implemented_yet
end

function assign(target, value)
    Expr(:(=), target, value)
end

function (<|)(f, arg)
    f(arg)
end

function gather(args)
    isempty(args) ? nothing :
    length(args) === 1 && args[1] isa Expr ? args[1] :
    Expr(:block, args...)

end

function for_iter(f :: Function, iter_arg, seq, body)
    basic = Expr(:for, assign(iter_arg, seq), body)
    token = mangle()
    result = mangle()
    check_break = Expr(
        :block,
        assign(token, Expr(:call, Ref, false)),
        assign(IS_BREAK, token),
        basic,
        f(token),
    )
end

function for_iter(iter_arg, seq, body)
    for_iter((_) -> nothing, iter_arg, seq, body)
end

function while_loop(f :: Function, cond, body)
    basic = Expr(:while, cond, body)
    token = mangle()
    result = mangle()
    check_break = Expr(:block,
        assign(token, Expr(:call, Ref, false)),
        assign(IS_BREAK, token),
        basic,
        f(token),
    )
end

function while_loop(cond, body)
    while_loop((_) -> nothing, cond, body)
end

function call(fn, args...)
    Expr(:call, fn, args...)
end

function as_global(names...)
    Expr(:global, names...)
end

function get_attr(expr, attr :: Symbol)
    Expr(:., expr, QuoteNode(attr))
end

function break!()
    Expr(:block, assign(get_attr(IS_BREAK, :x), true), Expr(:break))
end

function continue!()
    Expr(:continue)
end

function ifelse(cond, then, else_ :: Nothing)
    Expr(:if, cond, then)
end

function ifelse(cond, then, else_)
    Expr(:if, cond, then, else_)
end


function ifelse(cond, then)
    Expr(:if, cond, then)
end

function isinstance(inst, typs :: Union{Tuple, Vector})
    foldr(typs, init=true) do typ, last
        Expr(:||, isinstance(inst, typ), last)
    end
end

function isinstance(inst, typ)
    Expr(:call, isa, inst, typ)
end


function to_ast(filename, python :: Dict)

    tag_loc = @λ begin
        (if filename === nothing end &&
        Record(lineno, colno)) -> LineNumberNode(lineno)

        Record(lineno, colno) -> LineNumberNode(lineno, filename)

        _ -> nothing
    end

    function trans_block(seq)
        res = []
        for each in seq
            loc = tag_loc(each)
            if loc !== nothing
                push!(res, loc)
            end
            push!(res, apply(each))
        end
        res
    end

    apply = @λ begin
        (num :: Number)  -> num
        (str :: String)  -> str
        (:: Nothing)     -> nothing

        Record(:class => "Module", body) ->
                let body = gather <| trans_block(body)

                    filename === nothing ?
                    body                 :
                    Expr(:module, true, Symbol(filename), body)
                end

        Record(:class => "Name", id) ->
            Symbol(id)
        Record(:class => "Num", n) -> n

        Record(:class => "List", elts) ->
            Expr(:vect, map(apply, elts)...)

        Record(:class => "Tuple", elts) ->
            Expr(:tuple, map(apply, elts)..., )

        Record(:class => "Return", value) -> Expr(:return, apply(value))

        Record(:class => "arg", annotation, arg) -> Expr(:no_eval, Symbol(arg), apply(annotation))
        (Record(class,
                body,
                :args => Record(
                   kwarg,
                   args,
                   kw_defaults,
                   kwonlyargs,
                   defaults,
                   vararg
               )) && fn_ast) ->
             begin
                if kwarg === nothing && isempty(kwonlyargs)
                   if isempty(kw_defaults) && isempty(defaults)
                        f = @λ Expr(:no_eval, arg, annotation) -> (arg, annotation)
                        arg_anno = map(f ∘ apply, args)
                        args = map(first, arg_anno)
                        annos = [annotate(arg, anno) for (arg, anno) in arg_anno if anno !== nothing]

                        if class == "Lambda"
                            Expr(:function, Expr(:tuple, args...), Expr(:block, annos..., apply(body)))
                        else

                            body = gather <| trans_block(body)
                            decorator_list = fn_ast[:decorator_list]
                            fn_name = Symbol(fn_ast[:name])
                            init = Expr(:function, Expr(:call, fn_name, args...), Expr(:block, annos..., body))
                            reduce(decorator_list, init=init) do last, decorator
                                decorator = apply(decorator)
                                wrapped = call(decorator, last)
                                Expr(:(=), fn_name, Expr(:let, empty_block, wrapped))
                            end |> ret_nil
                        end
                   else
                        @not_implemented_yet
                   end
                else
                    @not_implemented_yet
                end
             end

        Record(:class   => "Assign", targets, value) ->
             (reduce(targets, init = apply(value)) do last, target
                Expr(:(=), apply(target), last)
             end |> ret_nil)

        Record(:class => "AugAssign", target, op, value) -> @not_implemented_yet

        Record(:class => "AnnAssign", target, annotation, value) ->
            (annotate(apply(target), apply(annotation)) |>
            target -> assign(target, value)            |>
            ret_nil)

        Record(:class => "For", target, iter, body, orelse) ->
            let target = apply(target),
                iter = apply(iter),
                body = gather <| trans_block(body),
                orelse = gather <| trans_block(orelse)

                for_iter(target, iter, body) do token
                    ifelse(Expr(:call, !, get_attr(token, :x)), orelse)
                end

            end

        Record(:class => "While", test, body, orelse) ->
            let cond = apply(test),
                body = gather <| trans_block(body),
                orelse = gather <| trans_block(body)

                 while_loop(cond, body) do token
                    ifelse(Expr(:call, !, get_attr(token, :x)), or_else)
                 end
            end

        Record(:class => "With") -> @not_implemented_yet

        Record(:class => "ClassDef") -> @not_implemented_yet

        Record(:class => "Try", body, handlers, orelse, finalbody) ->
            if !isempty(finalbody) || !isempty(orelse)
                @not_implemented_yet
            else
                ret = Expr(:try, gather <| trans_block(body))
                if isempty(handlers)
                    return ret
                end
                except = mangle()
                args = ret.args
                push!(args, except)
                init = call(throw, except)
                foldr(handlers, init = init) do handler, last
                    @match handler begin
                        Record(:type => exc, name, body) =>
                            let exc = apply(exc),

                                body = gather <| trans_block(body),

                                tc = isinstance(except, exc),

                                case = name === nothing ? body : gather([
                                    assign(name, except),
                                    body
                                ])

                                ifelse(tc, body, last)
                            end
                        _ => @error "Unknown python ast."
                    end
                end |> it -> push!(args, it)
                ret
            end

        # runtime error
        Record(:class => "Raise", :exc => nothing, :cause => nothing)   -> @not_implemented_yet

        Record(:class => "Raise", exc, :cause => nothing) -> call(throw, apply(exc))

        Record(:class => "Raise", :exc => _, :cause => _) -> @not_implemented_yet

        Record(:class => "Import") -> @not_implemented_yet

        Record(:class => "ImportFrom") -> @not_implemented_yet

        Record(:class => "Global", names) -> Expr(:global, map(Symbol, names))

        Record(:class => "Pass") -> nothing

        Record(:class => "Break") -> break!()

        Record(:class => "Continue") -> continue!()

        Record(:class => "If", test, body, orelse) ->
            let cond = apply(test),
                body = gather <| trans_block(body),
                orelse = gather <| trans_block(orelse)

                ret_nil <| ifelse(cond, body, orelse)
            end



        Record(:class => "Expr", value) -> ret_nil <| apply(value)

        Record(:class => "Starred", value) -> Expr(:..., apply(value))

        Record(:class => "Call", func, args, keywords) ->
            begin
                func = apply(func)
                args = map(apply, args)
                keywords = [(it[:arg], apply(it[:value])) for it in keywords]
                kw_unpack = [Expr(:..., snd) for (fst, snd) in keywords if fst === nothing]
                kw_args = [Expr(:kw, fst, snd) for (fst, snd) in keywords if fst !== nothing]
                Expr(:call, func, Expr(:parameters, kw_unpack...), args..., kw_args...)
            end
        Record(:class => "BinOp", op, left, right) ->
          let op =  @match op[:class] begin
               # TODO, binary operator in Python cannot be mapped to Julia directly.
               # We should implement Python.(+), Python.(-)...
               "Add"     => (+)
               "Sub"     => (-)
               "Mult"    => (*)
               "Div"     => (/)
               "MatMult" => @not_implemented_yet
               "Mod"     => (%)
               "Pow"     => (^)
               "LShift"  => (<<)
               "RShift"  => (>>)
               "BitOr"   => (|)
               "BitXor"  => xor
               "BitAnd"  => (&)
               "FloorDiv"=> floor ∘ (/)
          end
              call(op, apply(left), apply(right))
          end
        this ->
            let msg = "class: $(this[:class]), attributes: $(keys(this))."
                @match this begin
                    Dict(:class=>"Module") => println(:aaa)
                    ::T where T => println(T)
                end
                throw(msg)
            end
    end

    apply(python)
end

end # end compat_32842


end
