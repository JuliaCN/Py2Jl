
@testset "py2jl mod gen" begin
    mod = py2jl"""
    def sumBy(f, seq):
            s = 0
            for each in seq:
                s = s + each
            return s

        result = sumBy(lambda x: x + 1, [100, 200])
        print(result)
    """

    @testset "transpiled codes run in the pure Julia runtime" begin
        @test mod.result == 100
        @test mod.sumBy(identity, [1, 2, 3]) === 6
    end
end