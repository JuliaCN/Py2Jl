from __future__ import annotations
import typing
import ast
import pretty_doc as pd
from symtable import SymbolTable, Symbol, symtable
from symtable import Function as FunctionSymtable
from contextlib import contextmanager
from json import dumps as _dump_json


def escape_string(x: str):
    return _dump_json(x, ensure_ascii=False)

_d_comma_space = pd.comma * pd.space
_d_if = pd.seg("if")
_d_elif = pd.seg("elif")
_d_else = pd.seg("else")
_d_colon = pd.seg(":")
_d_semicolon = pd.seg(";")
_d_in = pd.seg("in")

PY_CONT = "PyContinuation"


def to_ident(s: str):
    if s.isidentifier() or s.replace('′', '').isidentifier(): # TODO: check julia identifier
        return s
    return f'var{escape_string(s)}'

class JLTarget:
    def __init__(self, x: pd.Doc):
        self.x = x

    @classmethod
    def name(cls, s: str):
        return cls(pd.seg(to_ident(s)))

    def assign(self, expr: JLExpr, *, const=False) -> JLStmt:
        if const:
            return JLStmt(pd.seg("const") + self.x + pd.seg("=") + expr.x)
        return JLStmt(self.x + pd.seg("=") + expr.x)

    def star(self):
        return JLTarget(pd.parens(self.x * pd.seg("...")))

    @classmethod
    def list(cls, *args: JLTarget):
        return JLExpr(pd.bracket(pd.seplistof(_d_comma_space, (arg.x for arg in args))))

    @classmethod
    def tuple(cls, *args: JLTarget):
        return JLTarget(pd.parens(pd.seplistof(_d_comma_space, (arg.x for arg in args)) * _d_comma_space))

class JLExpr:
    def __init__(self, x: pd.Doc):
        self.x = x

    def __call__(self, *args: JLExpr, **kwds: JLExpr):
        if not kwds:
            return JLExpr(self.x * pd.parens(pd.seplistof(_d_comma_space, (arg.x for arg in args))))

        return JLExpr(self.x * pd.parens(
            pd.seplistof(_d_comma_space, (arg.x for arg in args))
            * _d_semicolon
            * pd.seplistof(_d_comma_space, [pd.seg(k + " = ") * v.x for k, v in kwds.items()])
        ))

    def pycall(self, *args: JLExpr, **kwds: JLExpr):
        return self.mk_call(self, self.tuple(*args), self.namedtuple(**kwds))

    @property
    def doc(self):
        return self.x

    def isa(self, x: JLExpr):
        return JLExpr(pd.parens(self.x + pd.seg("isa") + x.x))

    def kw(self, name: JLExpr) -> JLExpr:
        return JLExpr(name.x + pd.seg("=") + self.x)

    def assign_to(self, *many_lhs: JLTarget) -> JLExpr:
        r = self.x
        for lhs in many_lhs:
            r = lhs.x + pd.seg("=") + r
        r += _d_semicolon
        
        return JLExpr(pd.parens(r))

    def attr(self, s: str):
        return JLExpr(self.x * pd.seg(".") * pd.seg(s))

    def attr_setter(self, s: str):
        return JLTarget(self.x * pd.seg(".") * pd.seg(s))
    
    def subscript(self, arg: JLExpr):
        return JLExpr(self.x * pd.bracket(arg.x))

    def subscript_setter(self, arg: JLExpr):
        return JLTarget(self.x * pd.bracket(arg.x))

    def star(self):
        return JLExpr(pd.parens(self.x * pd.seg("...")))

    def to_stmt(self):
        return JLStmt(self.x * _d_semicolon)

    @classmethod
    def name(cls, n: str):
        return cls(pd.seg(to_ident(n)))

    @classmethod
    def symbol(cls, s: str):
        return cls(pd.seg(":" + s))

    @classmethod
    def literal(cls, x: str):
        return cls(pd.seg(x))
    
    @classmethod
    def mk_call(cls, f: JLExpr, *args: JLExpr):
        return JLExpr(f.x * pd.parens(pd.seplistof(_d_comma_space, (arg.x for arg in args))))

    @classmethod
    def namedtuple(cls, **kwd: JLExpr):
        return JLExpr(pd.parens(_d_semicolon * pd.seplistof(_d_comma_space, [pd.seg(k + " = ") * v.x for k, v in kwd.items()])))

    @classmethod
    def namedtuple2(cls, *kwds: JLExpr):
        return JLExpr(pd.parens(_d_semicolon * pd.seplistof(_d_comma_space, (arg.x for arg in kwds))))

    @classmethod
    def tuple(cls, *args: JLExpr):
        if not args:
            return JLExpr.literal("()")
        return JLExpr(pd.parens(pd.seplistof(_d_comma_space, (arg.x for arg in args)) * _d_comma_space))

    @classmethod
    def list(cls, *args: JLExpr):
        return JLExpr(pd.bracket(pd.seplistof(_d_comma_space, (arg.x for arg in args))))

    @classmethod
    def typed_list(cls, t: JLExpr, *args: JLExpr):
        return JLExpr(t.x * pd.bracket(pd.seplistof(_d_comma_space, (arg.x for arg in args))))

    @classmethod
    def curly(cls, *args: JLExpr):
        return pd.brace(pd.seplistof(_d_comma_space, (arg.x for arg in args)))

    @classmethod
    def and_seq(cls, *args: JLExpr):
        return Intrinsic.and_seq(*args)

    @classmethod
    def or_seq(cls, *args: JLExpr):
        return Intrinsic.or_seq(*args)

    @classmethod
    def block(cls, *args: JLStmt):
        return JLExpr(pd.vsep([
            pd.seg("begin"),
            pd.indent(4, pd.vsep([arg.x for arg in args])),
            pd.seg("end")
        ]))

    @classmethod
    def bool(cls, b: bool):
        return cls(pd.seg("true" if b else "false"))

    

class JLStmt:
    def __init__(self, x: pd.Doc):
        self.x = x

    @classmethod
    def chanining_assign(cls, expr: JLExpr, *targets: JLTarget):
        r = expr.x
        for lhs in targets:
            r = lhs.x + pd.seg("=") + r
        return JLStmt(r)

    @classmethod
    def ln(cls, file: str, line: int):
        return JLStmt(pd.seg(f"# {file}, line {line}"))

    @classmethod
    def block(cls, *args: JLStmt):
        return JLStmt(pd.vsep([
            pd.seg("begin"),
            pd.indent(4, pd.vsep([arg.x for arg in args])),
            pd.seg("end")
        ]))

    @classmethod
    def declare_locals(cls, *names: str) -> list[JLStmt]:
        return [JLStmt(pd.seg(f"local {n}")) for n in names]

    @classmethod
    def declare_globals(cls, *names: str) -> list[JLStmt]:
        return [JLStmt(pd.seg(f"global {n}")) for n in names]
 
    @classmethod
    def ret(cls, args: JLExpr):
        return JLStmt(pd.seg("return") + args.x)


    @classmethod
    def whileloop(cls, cond: JLExpr, *args: JLStmt):
        return JLStmt(pd.vsep([
            pd.seg("@noscope") + pd.seg("while") + cond.x,
            pd.indent(4, pd.vsep([arg.x for arg in args])),
            pd.seg("end")
        ]))


    @classmethod
    def if_else(cls, *args: tuple[JLExpr, list[JLStmt]], orelse: None | list[JLStmt] =None):
        suite = []
        for i, (cond, body) in enumerate(args):
            head = _d_if if i == 0 else _d_elif
            suite.append(head + cond.x * _d_colon)
            suite.append(pd.indent(4, pd.vsep([ arg.x for arg in body ])))
        if orelse:
            suite.append(_d_else * _d_colon)
            suite.append(pd.indent(4, pd.vsep([ arg.x for arg in orelse ])))
        suite.append(pd.seg("end"))
        return JLStmt(pd.vsep(suite))

    @classmethod
    def try_catch(cls, try_body: list[JLStmt], catch: None | tuple[str, JLStmt], final: list[JLStmt]):
        if catch is None:
            if not final:
                return JLStmt.block(*try_body)
            else:
                return JLStmt(pd.vsep([
                    pd.seg("try"),
                    pd.indent(4, pd.vsep([arg.x for arg in try_body])),
                    pd.seg("finally"),
                    pd.indent(4, pd.vsep([arg.x for arg in final])),
                    pd.seg("end")
                ]))
        else:
            exception_name, exception_handle = catch
            if not final:
                return JLStmt(pd.vsep([
                    pd.seg("try"),
                    pd.indent(4, pd.vsep([arg.x for arg in try_body])),
                    pd.seg("catch") + JLTarget.name(exception_name).x,
                    pd.indent(4, exception_handle.x),
                    pd.seg("end")
                ]))
            else:
                return JLStmt(pd.vsep([
                    pd.seg("try"),
                    pd.indent(4, pd.vsep([arg.x for arg in try_body])),
                    pd.seg("catch") + JLTarget.name(exception_name).x,
                    pd.indent(4, exception_handle.x),
                    pd.seg("finally"),
                    pd.indent(4, pd.vsep([arg.x for arg in final])),
                    pd.seg("end")
                ]))


class Intrinsic:

    pycall = JLExpr(pd.seg("jpy_call"))
    bool = JLExpr(pd.seg("jpy_bool"))
    and_seq = JLExpr(pd.seg("@jpy_all"))
    or_seq = JLExpr(pd.seg("@jpy_any"))
    dict = JLExpr(pd.seg("jpy_dict"))
    # lambdef = JLExpr(pd.seg("@jpy_lambdef"))
    set = JLExpr(pd.seg("jpy_set"))
    list = JLExpr(pd.seg("jpy_list"))
    nonevalue = JLExpr(pd.seg("jpy_none"))
    yieldvalue = JLExpr(pd.seg("@jpy_yield"))
    yieldfrom = JLExpr(pd.seg("@jpy_yieldfrom"))
    literal = JLExpr(pd.seg("jpy_literal"))

    getiter = JLExpr(pd.seg("jpy_getiter"))
    movenext = JLExpr(pd.seg("jpy_movenext"))
    getcurrent = JLExpr(pd.seg("jpy_getcurrent"))

    addlist = JLExpr(pd.seg("jpy_addlist"))
    slice = JLExpr(pd.seg("jpy_slice"))

    binops : dict[object, JLExpr] = {
        ast.Add: JLExpr(pd.seg("jpy_add")),
        ast.Sub: JLExpr(pd.seg("jpy_sub")),
        ast.Mult: JLExpr(pd.seg("jpy_mul")),
        ast.MatMult: JLExpr(pd.seg("jpy_matmul")),
        ast.Div: JLExpr(pd.seg("jpy_div")),
        ast.Mod: JLExpr(pd.seg("jpy_mod")),
        ast.Pow: JLExpr(pd.seg("jpy_pow")),
        ast.LShift: JLExpr(pd.seg("jpy_lshift")),
        ast.RShift: JLExpr(pd.seg("jpy_rshift")),
        ast.BitOr: JLExpr(pd.seg("jpy_or")),
        ast.BitXor: JLExpr(pd.seg("jpy_xor")),
        ast.BitAnd: JLExpr(pd.seg("jpy_and")),
        ast.FloorDiv: JLExpr(pd.seg("jpy_floordiv")),
    }

    ibinops : dict[object, JLExpr] = {
        ast.Add: JLExpr(pd.seg("jpy_iadd")),
        ast.Sub: JLExpr(pd.seg("jpy_isub")),
        ast.Mult: JLExpr(pd.seg("jpy_imul")),
        ast.MatMult: JLExpr(pd.seg("jpy_imatmul")),
        ast.Div: JLExpr(pd.seg("jpy_idiv")),
        ast.Mod: JLExpr(pd.seg("jpy_imod")),
        ast.Pow: JLExpr(pd.seg("jpy_ipow")),
        ast.LShift: JLExpr(pd.seg("jpy_ilshift")),
        ast.RShift: JLExpr(pd.seg("jpy_irshift")),
        ast.BitOr: JLExpr(pd.seg("jpy_ior")),
        ast.BitXor: JLExpr(pd.seg("jpy_ixor")),
        ast.BitAnd: JLExpr(pd.seg("jpy_iand")),
        ast.FloorDiv: JLExpr(pd.seg("jpy_ifloordiv")),
    }

    uops : dict[object, JLExpr] = {
        ast.UAdd: JLExpr(pd.seg("jpy_pos")),
        ast.USub: JLExpr(pd.seg("jpy_neg")),
        ast.Invert: JLExpr(pd.seg("jpy_invert")),
        ast.Not: JLExpr(pd.seg("jpy_not")),
    }

    conjunctive_compare = JLExpr(pd.seg("@jpy_conjunctive_cmp"))

    compare_ops : dict[object, JLExpr] = {
        ast.Eq: JLExpr(pd.seg("jpy_eq")),
        ast.NotEq: JLExpr(pd.seg("jpy_ne")),
        ast.Lt: JLExpr(pd.seg("jpy_lt")),
        ast.LtE: JLExpr(pd.seg("jpy_le")),
        ast.Gt: JLExpr(pd.seg("jpy_gt")),
        ast.GtE: JLExpr(pd.seg("jpy_ge")),
        ast.Is: JLExpr(pd.seg("jpy_is")),
        ast.IsNot: JLExpr(pd.seg("jpy_isnot")),
        ast.In: JLExpr(pd.seg("jpy_in")),
        ast.NotIn: JLExpr(pd.seg("jpy_notin")),
    }


class JLGenerator:
    def call(self, f, args):
        pass

class Compiler:
    _static_lookup_tbl = {}

    def create_module(self):
        return pd.vsep([arg.x for arg in self.transform_stmt_list(self.node.body)])

    def __init__(self, src, filename):
        self.node: ast.Module = ast.parse(src)
        self.filename = filename
        self.is_gen = False
        self.gen_sym_cnt = 0

        self.symtbl = symtable(src, filename, "exec")
        self.cursor = 0
        self.records = []

    def parent(self) -> SymbolTable:
        return self.records[-1][2]

    def gensym(self, s: str):
        self.gen_sym_cnt += 1
        return f'.{s}_{self.gen_sym_cnt}'

    
    def forloop(self, target: JLTarget, iterable: JLExpr, *args: JLStmt):
        iterator = self.gensym("iter")
        xs = [
            JLTarget.name(iterator).assign(Intrinsic.getiter(iterable)),
            JLStmt.whileloop(
                Intrinsic.movenext(JLExpr.name(iterator)),
                target.assign(Intrinsic.getcurrent(JLExpr.name(iterator))),
                *args,
            )
        ]
        return JLStmt(pd.vsep([arg.x for arg in xs]))

    @typing.overload
    def lambdef(
        self,
        name: None,
        is_generator: bool,
        posonlyargs: list[str], kwonlyargs: list[str],
        vararg: str | None, kwargs: str | None,
        defaults: list[JLExpr], kwdefaults: list[JLExpr | None], body: list[JLStmt]) -> JLExpr: ...

    @typing.overload
    def lambdef(
        self,
        name: str,
        is_generator: bool,
        posonlyargs: list[str], kwonlyargs: list[str],
        vararg: str | None, kwargs: str | None,
        defaults: list[JLExpr], kwdefaults: list[JLExpr | None], body: list[JLStmt]) -> JLStmt: ...

    def lambdef(
        self,
        name: str | None,
        is_generator: bool,
        posonlyargs: list[str], kwonlyargs: list[str],
        vararg: str | None, kwargs: str | None,
        defaults: list[JLExpr], kwdefaults: list[JLExpr | None], body: list[JLStmt]):

        names_map: dict[str, str] = {}
        for i in range(len(posonlyargs)):
            old = posonlyargs[i]
            new = f"_{old}′"
            names_map[new] = old
            posonlyargs[i] = new
        
        for i in range(len(kwonlyargs)):
            old = kwonlyargs[i]
            new = f"_{old}′"
            names_map[new] = old
            kwonlyargs[i] = new
        
        if vararg:
            new = f"_{vararg}′"
            names_map[new] = vararg
            vararg = new
        if kwargs:
            new = f"_{kwargs}′"
            names_map[new] = kwargs
            kwargs = new

        expr_posonlyargs = [JLExpr.name(arg) for arg in posonlyargs]
        for i, e in enumerate(reversed(defaults)):
            expr_posonlyargs[-i] = e.kw(expr_posonlyargs[-i])
        
        expr_kwonlyargs = [JLExpr.name(arg) for arg in kwonlyargs]

        for i, e in enumerate(reversed(kwdefaults)):
            if e:
                expr_kwonlyargs[-i] = e.kw(expr_kwonlyargs[-i])
        
        if vararg:
            expr_posonlyargs.append(JLExpr.name(vararg).star())
        if kwargs:
            expr_kwonlyargs.append(JLExpr.name(kwargs).star())

        sig = pd.seplistof(_d_comma_space, [arg.x for arg in expr_posonlyargs])
        if expr_kwonlyargs:
            sig += _d_semicolon + pd.seplistof(_d_comma_space, [arg.x for arg in expr_kwonlyargs])
        
        
        expr_body: list[pd.Doc] = []

        for k, v in names_map.items():
            expr_body.append(JLTarget.name(v).assign(JLExpr.name(k)).x)
        
        if is_generator:  
            expr_body.extend(arg.x for arg in body)
            expr_body = [pd.vsep([
                pd.seg(f"Channel() do {PY_CONT}"),
                pd.indent(2, pd.vsep(expr_body)),
                pd.seg(f"end"),
            ])]
            
        else:
            expr_body.extend(arg.x for arg in body)

        if name is not None:
            n = self.parent().lookup(name)
            generated_name = to_ident(self.gensym(name))
            return JLStmt(pd.vsep([
                pd.seg("function") + pd.seg(generated_name) * pd.parens(sig),
                pd.indent(4, pd.vsep(expr_body)),
                pd.seg("end"),
                JLTarget.name(name).assign(JLExpr.literal(generated_name), const=n.is_global()).x,
            ]))
        else:
            return JLExpr(pd.vsep([
                pd.seg("(function") + pd.parens(sig),
                pd.indent(4, pd.vsep(expr_body)),
                pd.seg("end)"),
            ]))

    

    @contextmanager
    def enter(self):
        self.records.append((self.cursor, self.is_gen, self.symtbl))
        try:
            self.symtbl = self.symtbl.get_children()[self.cursor]
            self.cursor = 0
            self.is_gen = False
            yield
        finally:
            (self.cursor, self.is_gen, self.symtbl) = self.records.pop()
            self.cursor += 1
    
    def _static_lookup_method(self, n: str):
        if f := self._static_lookup_tbl.get(n):
            return f
        if f := getattr(self.__class__, "transform_" + n):
            self._static_lookup_tbl[n] = f
            return f
        raise LookupError(n)
    
    def transform_expr(self, x: ast.expr) -> JLExpr:
        assert isinstance(x, ast.expr)
        f = self._static_lookup_method(x.__class__.__name__)
        return f(self, x)

    def transform_expr_or_none(self, x: ast.expr | None) -> JLExpr:
        if x is None:
            return Intrinsic.nonevalue
        return self.transform_expr(x)

    
    def transform_stmt(self, x: ast.stmt) -> JLStmt:
        assert isinstance(x, ast.stmt)
        f = self._static_lookup_method(x.__class__.__name__)
        return f(self, x)
    
    def transform_lhs(self, x: ast.expr) -> JLTarget:
        assert isinstance(x, ast.expr)
        f = self._static_lookup_method(x.__class__.__name__)
        return f(self, x)

    def transform_lhs_list(self, x: list[ast.expr]) -> list[JLTarget]:
        return [self.transform_lhs(e) for e in x]

    def transform_expr_list(self, xs: typing.List[ast.expr]):
        return [self.transform_expr(e) for e in xs]
    
    def transform_stmt_list(self, xs: typing.List[ast.stmt]):
        result : list[JLStmt] = []
        for x in xs:
            result.append(JLStmt.ln(self.filename, x.lineno))
            result.append(self.transform_stmt(x))
        
        result.append(Intrinsic.nonevalue.to_stmt())
        return result
    

    def transform_BoolOp(self, x: ast.BoolOp):
        xs = list(map(self.transform_expr, x.values))
        if isinstance(x.op, ast.And):
            return JLExpr.and_seq(*xs)
        elif isinstance(x.op, ast.Or):
            return JLExpr.or_seq(*xs)
        else:
            raise NotImplementedError(x.op)

    def transform_NamedExpr(self, x: ast.NamedExpr) -> JLExpr:
        return self.transform_expr(x.value).assign_to(self.transform_lhs(x.target))
        
    def transform_BinOp(self, x: ast.BinOp) -> JLExpr:
        f = Intrinsic.binops[type(x.op)]    
        return f(self.transform_expr(x.left), self.transform_expr(x.right))

    def transform_UnaryOp(self, x: ast.UnaryOp) -> JLExpr:
        f = Intrinsic.uops[type(x.op)]
        return f(self.transform_expr(x.operand))

    def transform_IfExp(self, x: ast.IfExp) -> JLExpr:
        test = Intrinsic.bool(self.transform_expr(x.test)).x
        body = self.transform_expr(x.body).x
        orelse = self.transform_expr(x.orelse).x
        return JLExpr(
            pd.vsep(
                [
                    pd.seg("if") + test,
                    pd.indent(4, body),
                    pd.seg("else"),
                    pd.indent(4, orelse),
                    pd.seg("end")
                ]
        ))

    def transform_Dict(self, x: ast.Dict) -> JLExpr:
        args: list[pd.Doc] = []
        for (k, v) in zip(x.keys, x.values):
            if k is None:
                v = self.transform_expr(v)
                args.append(v.x * pd.seg("..."))
            else:
                k = self.transform_expr(k).x
                v = self.transform_expr(v).x
                args.append(k * pd.seg("=>") * v)
        return Intrinsic.dict(*map(JLExpr, args))

    def transform_Lambda(self, x: ast.Lambda) -> JLExpr:
        defaults = [self.transform_expr(d) for d in x.args.defaults]
        kwdefaults = [d and self.transform_expr(d) for d in x.args.kw_defaults]
        with self.enter():
            if x.args.args:
                raise NotImplementedError("so far only positional only args and keyword only args are supported")
            args = [a.arg for a in x.args.posonlyargs]
            kwonlyargs =  [a.arg for a in x.args.kwonlyargs]

            if x.args.kwarg:
                kwarg = x.args.kwarg.arg
            else:
                kwarg = None
            
            if x.args.vararg:
                vararg = x.args.vararg.arg
            else:
                vararg = None
            
            block : list[JLStmt] = []
            assert isinstance(self.symtbl, FunctionSymtable)
            block.extend(JLStmt.declare_locals(*self.symtbl.get_locals()))
            block.append(JLStmt.ret(self.transform_expr(x.body)))                
            
            return self.lambdef(
                None,
                self.is_gen,
                args,
                kwonlyargs,
                vararg,
                kwarg,
                defaults,
                kwdefaults,
                block,
            )

    def transform_Set(self, x: ast.Set) -> JLExpr:
        return Intrinsic.set(*map(self.transform_expr, x.elts))

    def _build_comp(self, xs: list[ast.comprehension], i: int, first_iter: JLExpr, result: JLStmt):
        x = xs[i]
        self.transform_expr(x.iter)
        cond = Intrinsic.bool(Intrinsic.and_seq(*map(self.transform_expr, x.ifs)))
        target = self.transform_lhs(x.target)
        if i == 0:
            iter = first_iter
        else:
            iter = self.transform_expr(x.iter)
        i += 1
        if i == len(xs):
            ret = result
        else:
            ret = self._build_comp(xs, i, first_iter, result)
        return self.forloop(target, iter, JLStmt.if_else((cond, [ret])))

        
    def transform_ListComp(self, x: ast.ListComp) -> JLExpr:
        x.generators
        first_iter = self.transform_expr(x.generators[0].iter)

        with self.enter():
            arg = JLExpr.name(".0")
            rhs_list = JLExpr.name(".1")
            lhs_list = JLTarget.name(".1")
            result = self.transform_expr(x.elt)
            result_action = Intrinsic.addlist(rhs_list, result).to_stmt()
            
            return self.lambdef(
                None,
                False,
                [".0"],
                [],
                None,
                None,
                [],
                [],
                [
                    lhs_list.assign(Intrinsic.list()),
                    self._build_comp(x.generators, 0, arg, result_action),
                    JLStmt.ret(rhs_list)
                ]
            )(first_iter)


    def transform_SetComp(self, x: ast.SetComp) -> JLExpr:
        raise NotImplementedError
    
    def transform_DictComp(self, x: ast.DictComp) -> JLExpr:
        raise NotImplementedError
    
    def transform_GeneratorExp(self, x: ast.GeneratorExp) -> JLExpr:
        raise NotImplementedError
    
    def transform_Yield(self, x: ast.Yield) -> JLExpr:
        self.is_gen = True
        if not x.value:
            value = Intrinsic.nonevalue
        else:
            value = self.transform_expr(x.value)
        
        return Intrinsic.yieldvalue(value)
    
    def transform_YieldFrom(self, x: ast.YieldFrom) -> JLExpr:
        return Intrinsic.yieldfrom(self.transform_expr(x.value))
    
    def transform_Await(self, x: ast.Await) -> JLExpr:
        raise NotImplementedError

    def transform_Compare(self, x: ast.Compare) -> JLExpr:
        last = self.transform_expr(x.left)
        args = []
        for i, op in enumerate(x.ops):
            f = Intrinsic.compare_ops[type(op)]
            cur = self.transform_expr(x.comparators[i])
            args.append(f(last, cur))
            last = cur
        return Intrinsic.and_seq(*args)

    def transform_Call(self, x: ast.Call) -> JLExpr:
        def mk_kwarg(k: ast.keyword):
            if k.arg is None:
                return self.transform_expr(k.value).star()
            return self.transform_expr(k.value).assign_to(JLTarget.name(k.arg))
        
        f = self.transform_expr(x.func)
        kwargs = JLExpr.namedtuple2(*map(mk_kwarg, x.keywords))
        args = JLExpr.tuple(*map(self.transform_expr, x.args))
        return Intrinsic.pycall(f, args, kwargs)

    def transform_FormattedValue(self, x: ast.FormattedValue) -> JLExpr:
        raise NotImplementedError
    
    def transform_JoinedStr(self, x: ast.JoinedStr) -> JLExpr:
        raise NotImplementedError

    def _const(self, v):
        if isinstance(v, str):
            return Intrinsic.literal(JLExpr.literal(escape_string(v)))
        elif isinstance(v, int):
            return Intrinsic.literal(JLExpr.literal(str(v)))
        elif isinstance(v, float):
            return Intrinsic.literal(JLExpr.literal(str(v)))
        elif isinstance(v, bool):
            return Intrinsic.literal(JLExpr.bool(v))
        elif v is None:
            return Intrinsic.nonevalue
        elif isinstance(v, bytes):
            return Intrinsic.literal(JLExpr.typed_list(JLExpr.literal("UInt8"), *map(JLExpr.literal, map(str, v))))
        elif isinstance(v, tuple):
            return Intrinsic.literal(JLExpr.tuple(*map(self._const, v)))
        else:
            raise NotImplementedError(type(v))
            
    def transform_Constant(self, x: ast.Constant) -> JLExpr:
        v = x.value
        return self._const(v)

    def transform_Attribute(self, x: ast.Attribute) -> JLExpr | JLTarget:
        value = self.transform_expr(x.value)
        if isinstance(x.ctx, ast.Load):
            return JLExpr.attr(value, x.attr)
        elif isinstance(x.ctx, ast.Store):
            return JLExpr.attr_setter(value, x.attr)
        else:
            raise NotImplementedError

    def transform_Subscript(self, x: ast.Subscript) -> JLExpr | JLTarget:
        value = self.transform_expr(x.value)
        slice = self.transform_expr(x.slice)
        if isinstance(x.ctx, ast.Load):
            return JLExpr.subscript(value, slice)
        elif isinstance(x.ctx, ast.Store):
            return JLExpr.subscript_setter(value, slice)
        else:
            raise NotImplementedError

    def transform_Starred(self, x: ast.Starred) -> JLExpr | JLTarget:
        if isinstance(x.ctx, ast.Load):
            return self.transform_expr(x.value).star()
        elif isinstance(x.ctx, ast.Store):
            return self.transform_lhs(x.value).star()
        else:
            raise NotImplementedError
    
    def transform_Name(self, x: ast.Name) -> JLExpr | JLTarget:
        if isinstance(x.ctx, ast.Load):
            return JLExpr.name(x.id)
        elif isinstance(x.ctx, ast.Store):
            return JLTarget.name(x.id)
        else:
            raise NotImplementedError

    def transform_List(self, x: ast.List) -> JLExpr | JLTarget:
        if isinstance(x.ctx, ast.Load):
            return Intrinsic.list(*map(self.transform_expr, x.elts))
        elif isinstance(x.ctx, ast.Store):
            return JLTarget.tuple(*map(self.transform_lhs, x.elts))
        else:
            raise NotImplementedError

    def transform_Tuple(self, x: ast.Tuple) -> JLExpr | JLTarget:
        if isinstance(x.ctx, ast.Load):
            return JLExpr.tuple(*map(self.transform_expr, x.elts))
        elif isinstance(x.ctx, ast.Store):
            return JLTarget.tuple(*map(self.transform_lhs, x.elts))
        else:
            raise NotImplementedError
    
    def transform_Slice(self, x: ast.Slice) -> JLExpr:
        lower = self.transform_expr_or_none(x.lower)
        upper = self.transform_expr_or_none(x.upper)
        step = self.transform_expr_or_none(x.step)
        return Intrinsic.slice(lower, upper, step)

    
    def transform_FunctionDef(self, x: ast.FunctionDef) -> JLStmt:
        defaults = [self.transform_expr(d) for d in x.args.defaults]
        kwdefaults = [d and self.transform_expr(d) for d in x.args.kw_defaults]
        with self.enter():
            if x.args.args:
                raise NotImplementedError("so far only positional only args and keyword only args are supported")
            args = [a.arg for a in x.args.posonlyargs]
            kwonlyargs =  [a.arg for a in x.args.kwonlyargs]

            if x.args.kwarg:
                kwarg = x.args.kwarg.arg
            else:
                kwarg = None
            
            if x.args.vararg:
                vararg = x.args.vararg.arg
            else:
                vararg = None
            
            block : list[JLStmt] = []
            assert isinstance(self.symtbl, FunctionSymtable)
            block.extend(JLStmt.declare_locals(*self.symtbl.get_locals()))
            block.extend(self.transform_stmt_list(x.body))
            
            return self.lambdef(
                x.name,
                self.is_gen,
                args,
                kwonlyargs,
                vararg,
                kwarg,
                defaults,
                kwdefaults,
                block,
            )

    def transform_Delete(self, x: ast.Delete) -> JLStmt:
        raise NotImplementedError

    def transform_Assign(self, x: ast.Assign) -> JLStmt:
        targets = self.transform_lhs_list(x.targets)
        value = self.transform_expr(x.value)
        return JLStmt.chanining_assign(value, *targets)
    
    def transform_AugAssign(self, x: ast.AugAssign) -> JLStmt:
        target = self.transform_lhs(x.target)
        rhs = self.transform_expr(x.target)
        value = self.transform_expr(x.value)
        op = Intrinsic.ibinops[type(x.op)]
        return target.assign(op(rhs, value))

    def transform_AnnAssign(self, x: ast.AnnAssign) -> JLStmt:
        if x.value:
            target = self.transform_lhs(x.target)
            value = self.transform_expr(x.value)
            return target.assign(value)
        else:
            return JLStmt(pd.empty)
    
    def transform_For(self, x: ast.For) -> JLStmt:
        target = self.transform_lhs(x.target)
        iter = self.transform_expr(x.iter)
        block = self.transform_stmt_list(x.body)
        return self.forloop(target, iter, *block)
    
    def transform_While(self, x: ast.While) -> JLStmt:
        if x.orelse:
            raise NotImplementedError("else clause in while loop")

        test = self.transform_expr(x.test)
        block = self.transform_stmt_list(x.body)
        return JLStmt.whileloop(test, *block)

    def _extract_if(self, x: ast.If):
        ifs : list[tuple[ast.expr, list[ast.stmt]]]= []
        xs: list[ast.stmt] = [x]
        while len(xs) == 1 and isinstance(xs[1], ast.If):
            node = xs[1]
            if isinstance(node, ast.If):
                xs = node.orelse
                ifs.append((node.test, node.body))
        return ifs, xs            

    def transform_If(self, x: ast.If) -> JLStmt:
        ifs, xs = self._extract_if(x)
        ifs = [(Intrinsic.bool(self.transform_expr(t)), self.transform_stmt_list(b)) for t, b in ifs]
        xs = self.transform_stmt_list(xs)
        return JLStmt.if_else(*ifs, orelse=xs)

    def transform_With(self, x: ast.With) -> JLStmt:
        raise NotImplementedError
    
    def transform_Match(self, x: ast.Match) -> JLStmt:
        raise NotImplementedError
    
    def transform_AsyncWith(self, x: ast.AsyncWith) -> JLStmt:
        raise NotImplementedError

    def transform_Raise(self, x: ast.Raise) -> JLStmt:
        if x.cause:
            raise NotImplementedError("cause in raise")
        if not x.exc:
            return JLExpr.literal("rethrow()").to_stmt()

        return JLExpr.literal("throw")(self.transform_expr(x.exc)).to_stmt()
    
    def _handle_exception(self, e: JLExpr, x: ast.ExceptHandler):
        """
        'e' should be single form
        """
        if not x.type:
            cond = JLExpr.bool(True)
        else:
            cond = e.isa(self.transform_expr(x.type))
        block: list[JLStmt] = []
        if x.name:
            block.append(JLTarget.name(x.name).assign(e))

        block.extend(self.transform_stmt_list(x.body))
        return cond, block



    def transform_Try(self, x: ast.Try) -> JLStmt:
        body = self.transform_stmt_list(x.body)
        if x.orelse:
            raise NotImplementedError
        
        catch = None
        if x.handlers:
            e_name = self.gensym("exception")
            e_rhs = JLExpr.name(e_name)
            handlers = [self._handle_exception(e_rhs, h) for h in x.handlers]
            catch = e_name, JLStmt.if_else(*handlers, orelse=[JLExpr.literal("rethrow()").to_stmt()])

        finalbody = self.transform_stmt_list(x.finalbody)
        return JLStmt.try_catch(body, catch, finalbody)

    def transform_Assert(self, x: ast.Assert) -> JLStmt:
        raise NotImplementedError
    
    def transform_Import(self, x: ast.Import) -> JLStmt:
        raise NotImplementedError
    
    def transform_ImportFrom(self, x: ast.ImportFrom) -> JLStmt:
        raise NotImplementedError
    
    def transform_Global(self, x: ast.Global) -> JLStmt:
        return JLStmt(pd.vsep([arg.x for arg in JLStmt.declare_globals(*x.names)]))
    
    def transform_Nonlocal(self, x: ast.Nonlocal) -> JLStmt:
        return JLStmt(pd.empty)
    
    def transform_Expr(self, x: ast.Expr) -> JLStmt:
        return self.transform_expr(x.value).to_stmt()
    
    def transform_Pass(self, x: ast.Pass) -> JLStmt:
        return JLStmt(pd.empty)
    
    def transform_Break(self, x: ast.Break) -> JLStmt:
        return JLStmt(pd.seg("break"))
    
    def transform_Continue(self, x: ast.Continue) -> JLStmt:
        return JLStmt(pd.seg("continue"))
    
    def transform_Return(self, x: ast.Return) -> JLStmt:
        return JLStmt.ret(self.transform_expr_or_none(x.value))
