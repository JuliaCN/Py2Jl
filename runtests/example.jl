using Py2JlRuntime
# .\runtests\example.jl, line 1
function var".f_1"(_x′, _y′)
    x = _x′
    y = _y′
    local x
    local y
    # .\runtests\example.jl, line 2
    return jpy_add(x, y)
    jpy_none;
end
const f = var".f_1"
# .\runtests\example.jl, line 4
function var".g_2"(_x′ ; _y′ = jpy_literal(2))
    x = _x′
    y = _y′
    local x
    local y
    # .\runtests\example.jl, line 5
    return jpy_call(f, (x, y, ), (;))
    jpy_none;
end
const g = var".g_2"
# .\runtests\example.jl, line 7
function var".range_3"(_n′)
    Channel() do PyContinuation
      n = _n′
      local n
      local i
      # .\runtests\example.jl, line 8
      i = jpy_literal(0)
      # .\runtests\example.jl, line 9
      @noscope while @jpy_all(jpy_lt(i, n))
          # .\runtests\example.jl, line 10
          @jpy_yield(i);
          # .\runtests\example.jl, line 11
          i = jpy_iadd(i, jpy_literal(1))
          jpy_none;
      end
      jpy_none;
    end
end
const range = var".range_3"
# .\runtests\example.jl, line 12
s = jpy_literal(0)
# .\runtests\example.jl, line 13
var".iter_4" = jpy_getiter(jpy_list(jpy_literal(1), jpy_literal(2), jpy_literal(3)))
@noscope while jpy_movenext(var".iter_4")
    e = jpy_getcurrent(var".iter_4")
    # .\runtests\example.jl, line 14
    s = jpy_add(s, jpy_call(g, (e, ), (;)))
    jpy_none;
end
# .\runtests\example.jl, line 16
d = jpy_dict(jpy_literal(1)=>jpy_literal(2), jpy_literal(3)=>jpy_literal(4))
# .\runtests\example.jl, line 18
jpy_call(println, (s, ), (;));
# .\runtests\example.jl, line 19
jpy_call(println, (d[jpy_literal(3)], ), (;));
jpy_none;
