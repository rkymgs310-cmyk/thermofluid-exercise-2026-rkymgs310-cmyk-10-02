# 入力と手計算値はAI協働による提案。本人のレビューは学習ログで確認する。
using Test

if !isdefined(Main, :N01LinearAdvection)
    include(joinpath(@__DIR__, "run.jl"))
end

@testset "N01 必須テスト" begin
    @testset "矩形初期条件：両端を含む区間" begin
        x = [-1.0, -0.5, 0.0, 0.5, 1.0]
        original = copy(x)
        u = N01LinearAdvection.rectangular_initial_condition(
            x; base = -1.0, plateau = 3.0, plateau_start = -0.5, plateau_end = 0.5,
        )
        @test u == [-1.0, 3.0, 3.0, 3.0, -1.0]
        @test x == original
    end

    @testset "風上1ステップ：C=0.5" begin
        old = [1.0, 2.0, 4.0, 3.0, 1.0]
        original = copy(old)
        new = fill(NaN, 5)
        # 内部は2-0.5*(2-1)、4-0.5*(4-2)、3-0.5*(3-4)。
        @test N01LinearAdvection.upwind_step!(new, old, 2.0, 0.125, 0.5) === new
        @test new == [1.0, 1.5, 3.0, 3.5, 1.0]
        @test old == original
    end

    @testset "中心1ステップ：同じ旧配列・C=0.5" begin
        old = [1.0, 2.0, 4.0, 3.0, 1.0]
        original = copy(old)
        new = fill(NaN, 5)
        # 内部は2-0.25*(4-1)、4-0.25*(3-2)、3-0.25*(1-4)。
        @test N01LinearAdvection.centered_step!(new, old, 2.0, 0.125, 0.5) === new
        @test new == [1.0, 1.25, 3.75, 3.75, 1.0]
        @test old == original
    end

    @testset "左固定・右ゼロ勾配の境界" begin
        u = [9.0, 2.0, 4.0, 8.0, 7.0]
        @test N01LinearAdvection.apply_boundary!(u; left_value = 1.0) === u
        @test u == [1.0, 2.0, 4.0, 8.0, 8.0]
    end

    @testset "標準条件の安定・不安定比較と時刻" begin
        upwind = N01LinearAdvection.simulate(; scheme = :upwind)
        centered = N01LinearAdvection.simulate(; scheme = :centered)
        # 丸め誤差程度を許容し、中心の範囲逸脱は1以上を要求する。
        @test upwind.minimum >= 1.0 - 1e-12
        @test upwind.maximum <= 2.0 + 1e-12
        @test centered.minimum < 0.0
        @test centered.maximum > 3.0
        for result in (upwind, centered)
            @test result.steps == 40
            @test result.dt ≈ 0.0125
            @test result.dx ≈ 0.025
            @test result.cfl ≈ 0.5
            @test isapprox(result.steps * result.dt, 0.5; atol = 100eps())
        end
    end
end

@testset "N01 自作テスト：C=1なら風上更新は1格子の移送" begin
    old = [1.0, 4.0, 2.0, 8.0, 1.0]
    original = copy(old)
    new = fill(NaN, 5)
    # C=1では内部は旧値の左隣そのもの。境界適用前は両端を保持する。
    N01LinearAdvection.upwind_step!(new, old, 1.0, 0.25, 0.25)
    @test new == [1.0, 1.0, 4.0, 2.0, 1.0]
    @test old == original
end
