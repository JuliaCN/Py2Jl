
@testset "py2jl mod gen" begin
    py2jl"""
def sumBy(f, seq):
    s = 0
    for each in seq:
        s = s + f(each)
    return s

result = sumBy(lambda x: 1 + x, [100, 200])
    """
    @testset "transpiled codes run in the pure Julia runtime" begin
        @test result == 302
        @test sumBy(identity, [1, 2, 3]) === 6
    end
end