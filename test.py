from Py2Jl import Compiler
src = """

def f(x, y, /):
    return x + 1

def g(x, /, *, y=2):
    return f(x, y)

def sum_by(f, seq, /):
    for e in seq:
        s = s + g(e)
    return s

c = 1
for i in range(10):
    c += i

def f():
    yield 1
    yield
"""
k = Compiler(src, "a.py")


k.create_module().render(lambda x: print(x, end=''))