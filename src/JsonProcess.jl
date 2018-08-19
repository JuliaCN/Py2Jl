module Process

export from_file
using JSON
using MLStyle

function preprocess_to_atom_key(dict :: Any)
    @match dict begin
        Dict("type" => "complex", "real" => real, "imag" => imag) =>
            real + (imag)im
        it::Dict    =>
            map(collect(it)) do (key, value)
                Symbol(key), preprocess_to_atom_key(value)
            end |> Dict
        lst::Vector =>
            map(preprocess_to_atom_key, lst)
        _  in it => it
    end
end

function from_file(filename)
    preprocess_to_atom_key(JSON.Parser.parsefile(filename))
end


end