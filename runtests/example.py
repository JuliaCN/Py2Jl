def f(x, y, /):
    return x + y

def g(x, /, *, y=2):
    return f(x, y)

def range(n, /):
    i = 0
    while i < n:
        yield i
        i += 1

s = 0
for e in [1, 2, 3]:
    s = s + g(e)

d = {1: 2, 3: 4}

println(s)
println(d[3])
