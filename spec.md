
# Py2Jl specifications

## Goals

Firstly I want to clarify that **Not All The Python Module** could be transformed to julia **By Compiling**,
for the following reasons:

- Dynamic import mechanism

- External extension

- Dependency on implementation-specific behaviour

In fact it's possible to support above ones if we completely implement a Python in Julia.

As a consequence, we should set a range of compilable Python programs.

The identical features of compilable Python module are listed here.

- Module import could be resolved before runtime, or users explicitly tell the rules to resolve dynamic modules.

- Module import refers to no external extension, or users explicitly tell the rules to load the external extensions.

- Module import contains no implementation-specific behaviour.

Additionally, the module `builtin` is actually an external extension, as well as it could be also regarded as implementation-specific stuffs.
However, a mapping that keeps structure of potential referenced Python programs from `builtin` module is not difficult to make,
and we will supply a default one.

Finally, we should guarantee to compile all the Python programs to Julia with a consistency of functionality if above three conditions are satisfied.