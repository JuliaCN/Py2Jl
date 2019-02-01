using Py2Jl
py2jl"""
def sum_by(f, seq):
    s = 0
    for e in seq:
        s = s + f(e)
    return s
result = sum_by(lambda x: x * 10, [1, 2, 3])
"""
@info :print_result result

@info :interops sum_by(x -> 2x, [1, 2, 3])


@info transpiled_to_julia py2jl("mymod", """
def sum_by(f, seq):
    s = 0
    for e in seq:
        s = s + f(e)
    return s
""")
