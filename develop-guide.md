
## Python ASDL

https://github.com/python/cpython/blob/master/Parser/Python.asdl  

With this you can get a clear understanding of python's ast.


- Additional suggestions for Python: `astpretty`, `ast.parse`

```python
integrated-terminal> from astpretty import pprint as pp
integrated-terminal> from ast import parse as p
integrated-terminal> from toolz import compose
integrated-terminal> q = compose(pp, p)
integrated-terminal> q("for a, b in s : a")
Module(
    body=[
        For(
            lineno=1,
            col_offset=0,
            target=Tuple(
                lineno=1,
                col_offset=4,
                elts=[
                    Name(lineno=1, col_offset=4, id='a', ctx=Store()),
                    Name(lineno=1, col_offset=7, id='b', ctx=Store()),
                ],
                ctx=Store(),
            ),
            iter=Name(lineno=1, col_offset=12, id='s', ctx=Load()),
            body=[
                Expr(
                    lineno=1,
                    col_offset=15,
                    value=Name(lineno=1, col_offset=15, id='a', ctx=Load()),
                ),
            ],
            orelse=[],
        ),
    ],
)
```


- Additional suggestions from Julia:

```julia
julia> macro q(a) dump(a) end
julia> @q while x
          x + 1
          continue 2
          end
Expr
  head: Symbol while
  args: Array{Any}((2,))
    1: Symbol x
    2: Expr
      head: Symbol block
      args: Array{Any}((4,))
        1: LineNumberNode
          line: Int64 2
          file: Symbol REPL[38]
        2: Expr
          head: Symbol call
          args: Array{Any}((3,))
            1: Symbol +
            2: Symbol x
            3: Int64 1
        3: LineNumberNode
          line: Int64 3
          file: Symbol REPL[38]
        4: Expr
          head: Symbol continue
          args: Array{Any}((0,))
```
