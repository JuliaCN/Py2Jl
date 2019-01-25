module Py2Jl
export from_file, to_ast, process, @py2jl_str

include("Process.jl")
include("ASTGen.jl")

using .Process
using .ASTGen

mutable struct ModRefHelper end
"""
eg.
> mod = py2l\"\"\"
    def sumBy(f, seq):
        s = 0
        for each in seq:
            s = s + each
        return s

    result = sumBy(lambda x: x + 1, [100, 200])
    print(result)
  \"\"\"
> 300
> mod.sumBy(identity, [1, 2, 3])
> 6
"""
macro py2jl_str(code)
    mod_name_unique = Int(pointer_from_objref(ModRefHelper()))
    mod_name = "Py2Jl$mod_name_unique"
    node = to_ast(mod_name, process(code))
    println(node)
    esc(node)
end


end # module
