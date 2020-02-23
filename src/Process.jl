

#=
This module doesn't work until now for PyCall works ill.
However if you include it in Main, everything is okay.
=#

module Process
export to_dict, process
using PyCall



function to_dict(py_obj :: PyObject) :: Any

    pisa = pybuiltin("isinstance")
    phas = pybuiltin("hasattr")
    ast = pyimport("ast")
    AST = ast.AST
    if pisa(py_obj, AST)

        ty     = py_obj.__class__.__name__
        fields = py_obj._fields |> collect
        map(fields) do field
            field = Symbol(field)
            value = getproperty(py_obj, field)
            field =>
                if value isa Vector || value isa Tuple
                    map(to_dict, value)
                else
                    value |> to_dict
                end
        end |>
        function (iteritems)
            dict = Dict{Symbol, Any}(iteritems)
            if phas(py_obj, "lineno")
                dict[:lineno] = py_obj.lineno
            end
            if phas(py_obj, "col_offset")
                dict[:colno] = py_obj.col_offset
            end
            dict[:class] = ty
            dict
        end
    else
        @error "Invalid pyobj. Expected $(string(AST)), got $(py_obj.__class__)."
    end
end

to_dict(num :: Number) = num
to_dict(str :: String) = str
to_dict(::Nothing) = nothing

function process(codes:: String)

    ast = pyimport("ast")
    node = ast.parse(codes)
    to_dict(node)
end

end