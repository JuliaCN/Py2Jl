def sum_by(f, xs, /):
    s = 0
    for e  in xs:
        s = s + f(e)
    return s
