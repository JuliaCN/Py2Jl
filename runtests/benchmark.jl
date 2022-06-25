using Py2JlRuntime
# runtests/benchmark.jl, line 1
function var".sum_by_2"(_f′, _xs′)
    f = _f′
    xs = _xs′
    local f
    local xs
    local s
    local e
    # runtests/benchmark.jl, line 2
    s = jpy_literal(0)
    # runtests/benchmark.jl, line 3
    var".iter_1" = jpy_getiter(xs)
    @noscope while jpy_movenext(var".iter_1")
        e = jpy_getcurrent(var".iter_1")
        # runtests/benchmark.jl, line 4
        s = jpy_add(s, jpy_call(f, (e, ), (;)))
        jpy_none;
    end
    # runtests/benchmark.jl, line 5
    return s
    jpy_none;
end
const sum_by = var".sum_by_2"
jpy_none;
