module Py2JlRuntime
export @noscope
export PyIterator, PyVector
export @jpy_yield, @jpy_yieldfrom, jpy_literal, jpy_addlist, jpy_slice, jpy_getiter, jpy_movenext, jpy_getcurrent, jpy_call, jpy_bool, jpy_none, @jpy_all, jpy_dict, jpy_set, jpy_list, @jpy_any, jpy_add, jpy_sub, jpy_mul, jpy_floordiv, jpy_div, jpy_iadd, jpy_isub, jpy_imul, jpy_ifloordiv, jpy_idiv, jpy_pos, jpy_neg, jpy_invert, jpy_not, jpy_eq, jpy_ne, jpy_lt, jpy_le, jpy_gt, jpy_ge, jpy_isnot, jpy_is, jpy_in, jpy_notin, @jpy_conjunctive_cmp

macro noscope(ex)
    Meta.isexpr(ex, :while) || error("noscope: only use for while")
    cond = ex.args[1]
    body = ex.args[2]
    l1 = gensym("loopsetup")
    l2 = gensym("loopend")
    
    Expr(:block,
        Expr(:symboliclabel, l1),
        Expr(:if, cond, Expr(:block, body), Expr(:symbolicgoto, l2)),
        Expr(:symbolicgoto, l1),
        Expr(:symboliclabel, l2),
    ) |> esc
end
mutable struct PyIterator{V, E}
    self :: V
    state :: Union{E, Nothing}
end

struct PyVector{T}
    inner :: Vector{T}
end

@inline Base.iterate(x::PyVector, args...) = iterate(x.inner, args...)
@inline Base.getindex(x::PyVector, i::Integer) = getindex(x.inner, i+1)
@inline Base.setindex!(x::PyVector, v, i::Integer) = setindex!(x.inner, v, i+1)
@inline Base.push!(x::PyVector, args...) = push!(x.inner, args...)
@inline Base.pop!(x::PyVector, args...) = pop!(x.inner, args...)
@inline Base.eltype(x::PyVector) = eltype(x.inner)
@inline Base.length(x::PyVector) = length(x.inner)

macro jpy_yield(v)
    esc(:($put!(PyContinuation, $v)))
end

macro jpy_yieldfrom(v)
    iter = gensym(:iter)
    esc(quote
        $iter = $jpy_getcurrent(v)
        while $jpy_movenext($iter)
            $jpy_yield($jpy_getcurrent($iter))
        end
    end)
end

@inline function jpy_literal(x)
    x
end

Base.@pure function _infer_state_type(@nospecialize(t))
    Base.Core.Compiler._return_type(Base.iterate, (t, ))
end

@inline function jpy_addlist(x, y)
    push!(x, y)
end

@inline function jpy_slice(x, start, stop, step)
    if start === jpy_none
        start = 0
    end
    if stop === jpy_none
        stop = length(x)-1
    end
    if step === jpy_none
        step = 1
    end
    return x[start:step:stop]
    
end


@inline function jpy_getiter(x::T) where T
    PyIterator{T, _infer_state_type(T)}(x, nothing)
end

@inline function jpy_movenext(x::PyIterator)
    state = if x.state === nothing
        iterate(x.self)
    else
        iterate(x.self, x.state[2])
    end
    if isnothing(state)
        return false
    end
    x.state = state
    return true
end

@inline function jpy_getcurrent(x::PyIterator)
    return x.state[1]
end

@inline function jpy_call(f, args, kwargs)
    f(args...; kwargs...)
end

@inline function jpy_bool(x::Bool)
    x
end

@inline function jpy_bool(x::Union{AbstractVector, AbstractSet, AbstractDict})
    isempty(x)
end

@inline function jpy_bool(x::Tuple)
    isempty(x)
end

const jpy_none = nothing

macro jpy_all(xs...)
    foldr(xs) do (l, r)
        left = gensym(:left)
        Expr(:block,
            :($left = $l),
            :(if $jpy_bool($left)
                $r
            else 
                left
            end)
        )
    end |> esc
end

@inline function jpy_dict(xs...)
    Dict(xs...)
end


@inline function jpy_set(xs...)
    Set(xs)
end

@inline function jpy_list(xs...)
    PyVector(collect(xs))
end

macro jpy_any(xs...)
    foldr(xs) do (l, r)
        left = gensym(:left)
        Expr(:block,
            :($left = $l),
            :(if $jpy_bool($left)
                $left
            else 
                $r
            end))
    end |> esc
end

@inline jpy_add(a, b) = a + b
@inline jpy_sub(a, b) = a - b
@inline jpy_mul(a, b) = a * b
@inline jpy_floordiv(a, b) = div(a, b)
@inline jpy_div(a, b) = a / b

@inline jpy_iadd(a, b) = jpy_add(a, b)
@inline jpy_isub(a, b) = jpy_sub(a, b)
@inline jpy_imul(a, b) = jpy_mul(a, b)
@inline jpy_ifloordiv(a, b) = jpy_floordiv(a, b)
@inline jpy_idiv(a, b) = jpy_div(a, b)

@inline jpy_pos(a) = +a
@inline jpy_neg(a) = -a
@inline jpy_invert(a) = ~a
@inline jpy_not(a) = !jpy_bool(a)
@inline jpy_eq(a, b) = a == b
@inline jpy_ne(a, b) = a != b
@inline jpy_lt(a, b) = a < b
@inline jpy_le(a, b) = a <= b
@inline jpy_gt(a, b) = a > b
@inline jpy_ge(a, b) = a >= b
@inline jpy_isnot(a, b) = a !== b
@inline jpy_is(a, b) = a === b
@inline jpy_in(a, b) = a in b
@inline jpy_notin(a, b) = !(a in b)


macro jpy_conjunctive_cmp(op, args...)
    xs = []
    for i = 1:length(args)-1
        push!(xs, :($op($(args[i]), $(args[i+1]))))
    end
    return esc(Expr(:&&, xs...))
end


end # module
