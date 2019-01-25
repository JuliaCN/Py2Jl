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

module Config
    verbose = false

    verbose!() = begin
       global verbose = true;
    end

    not_verbose() = begin
        global verbose = false;
    end

    verbose = false
end

macro py2jl_str(code)
    node = to_ast(nothing, process(code))
    if Config.verbose
        println(node)
    end
    esc(node)
end


end # module
