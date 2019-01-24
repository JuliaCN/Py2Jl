using Test

using PyCall


@pyimport builtins
@pyimport ast

pisa = builtins.isinstance
phas = builtins.hasattr

to_dict(py_obj :: PyObject) :: Any = if pisa(py_obj, ast.AST)
        ty     = py_obj[:__class__]
        fields = py_obj[:_fields] |> collect

        map(fields) do field

            field = Symbol(field)
            value = py_obj[field]

            field =>
                if value isa Vector
                    map(to_dict, value)
                else
                    value |> to_dict
                end
        end |>
        function (iteritems)
            dict = Dict{Symbol, Any}(iteritems)
            if phas(py_obj, "lineno")
                dict[:lineno] = py_obj[:lineno]
            end
            if phas(py_obj, "col_offset")
                dict[:colno] = py_obj[:col_offset]
            end
            dict[:type] = ty
            dict
        end
    else
        @error "Invalid pyobj. Expected $(ast.AST), got $(py_obj[:__class__])."
    end

to_dict(num :: Number) = num
to_dict(str :: String) = str

node = ast.parse("f(x) + 1")
result = to_dict(node)
@info result
