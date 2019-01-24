using JSON
using MLStyle
import Base: show
include("src/Py2Jl.jl")

using .Py2Jl
#

dict = process("""
def sumBy(f, seq):
    s = 0
    for each in seq:
        s = s + each
    return s

result = sumBy(lambda x: x + 1, [100, 200])
print(result)

""")



println(to_ast("emmm", dict))
