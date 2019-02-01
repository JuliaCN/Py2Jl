include("src/Py2Jl.jl")
using .Py2Jl

Py2Jl.Config.verbose!()


py2jl"""
def sumBy(f, seq):
    s = 0
    for each in seq:
        s = s + each
    return s



result = sumBy(lambda x: x + 1, [100, 200])


"""

println("")
@info :interops

println(result, "  ", result)
println(sumBy(identity, 1:100))