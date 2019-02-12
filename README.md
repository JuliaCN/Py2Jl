# Py2Jl

Python-to-Julia transpiler.

[![Preview](./preview.png)](./preview.png)

## Usage

```shell
pkg> add PyCall JSON MLStyle
julia> ENV["PYTHON"] = raw"<your python exe path>"
pkg> build PyCall
pkg> add https://github.com/JuliaCN/Py2Jl.jl#master
```

To demonstrate, open a file (check out [demo.jl](./demo.jl)) and write

```julia
using Py2Jl

py2jl"""
def sum_by(f, seq):
    s = 0
    for e in seq:
        s = s + f(e)
    return s
"""
@info sum_by(x -> 2x, [1, 2, 3]) # 12

@info py2jl("mymod", """
def sum_by(f, seq):
    s = 0
    for e in seq:
        s = s + e
    return s
""")
```

Then type `julia demo.jl` in your shell to see the results.

## Motivation

Since packages written in Julia are quite few, and Python is exactly a subset of 
Julia despite some implementation details, it's natural to think about taking
advantage of existing Python codebase in Julia ecosystem so that we can have a
great number of powerful and battle-tested packages.

## Status

Currently, we can transpile a single Python module with limited constructs into 
Julia ones.

## Supported Features

- All the basic constructs like `if-else`, `for`, `while`, etc
- `while-else`, `for-else` constructs
- Function invocation with keyword args and variadic args
- Arbitrary `try-except`s
- Annotation (but not equivalent to Julia's)

## Not Implemented Features

- Function definitions with keyword args (both `kwargs` and so-called
`keyword arg`), default args and variadic args
- Classes
- Imports (dynamically importing might not be supported forever)
- Attributes (`obj.attr`)
- Python-compatible built-in functions like `map`, `print` and many standard
libs
