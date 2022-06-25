from wisepy2 import wise
from Py2Jl import Compiler
import sys

def py2jl(filename: str, out: str):
    with open(filename, 'r', encoding='utf-8') as f:
        code = f.read()
    with open(out, 'w', encoding='utf-8') as f:
        f.write("using Py2JlRuntime\n")
        doc = Compiler(code, out).create_module()
        doc.render(f.write)  # type: ignore
    
if __name__ == '__main__':
    wise(py2jl)()  # type: ignore