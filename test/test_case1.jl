
@testset "py2jl mod gen" begin
    py2jl"""
def sumBy(f, seq):
    s = 0
    for each in seq:
        s = s + f(each)
    return s

result = sumBy(lambda x: 1 + x, [100, 200])
    """
    @testset "transpiled codes run in the pure Julia runtime[1]" begin
        @test result == 302
        @test sumBy(identity, [1, 2, 3]) === 6
    end

    py2jl"""
def sum_by(f, seq):
    s = 0
    for e in seq:
        s = s + f(e)
    return s
result = sum_by(lambda x: x * 10, [1, 2, 3])
    """

     @testset "transpiled codes run in the pure Julia runtime[2]" begin
        @test result == 60
        @test sum_by(identity, [1, 2, 3]) === 6
    end

    py2jl"""
def __BOND_repl():
    SENTINEL = 1
    while SENTINEL>1:
        SENTINEL = 2
    return SENTINEL
"""
    @testset "while & compare" begin
        @test __BOND_repl() == 1
    end

    py2jl"""
    def __BOND_repl():
        SENTINEL = 10
        while True:
            break
        return SENTINEL
    """
    @testset "True" begin
            @test __BOND_repl() == 10
    end
end