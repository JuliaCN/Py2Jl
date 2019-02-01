using Py2Jl
py2jl"""
def sum_by(f, seq):
    s = 0
    for e in seq:
        s += e
    return s
"""

@info sum_by(x -> 2x, [1, 2, 3])

@info println(py2jl("mymod", """
def sum_by(f, seq):
    s = 0
    for e in seq:
        s += e
    return s
"""))
