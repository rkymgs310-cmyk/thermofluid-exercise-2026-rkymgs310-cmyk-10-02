# 必須テストは提供済みの期待値で確認します。末尾の自作テストだけを受講生が編集します。
# 入力の準備 → 独立した期待値との比較 → 入力保持・不正入力の確認の順に読みます。

using Test
if !isdefined(Main, :N02NonlinearAdvection)
    include(joinpath(@__DIR__, "run.jl"))
end
using .N02NonlinearAdvection
@testset "N02 必須テスト" begin
    @testset "流束と周期添字" begin
        @test burgers_flux(1.) == 0.5
        @test burgers_flux(2.) == 2.
        @test periodic_left_index(1, 4) == 4
        @test periodic_left_index(3, 4) == 2
    end
    @testset "保存形1ステップと旧配列不変" begin
        old = [1., 2., 1., 1.]
        saved = copy(old)
        new = similar(old)
        nonlinear_upwind_step!(new, old, 0.25, 1.; boundary = :periodic)
        @test new == [1., 1.625, 1.375, 1.]
        @test old == saved
    end
    @testset "定数場と境界条件" begin
        for (boundary, value) in ((:fixed, 1.), (:periodic, 0.7))
            old = fill(value, 5)
            new = similar(old)
            nonlinear_upwind_step!(new, old, 0.2, 1.; boundary)
            apply_boundary!(new; boundary)
            @test new ≈ old
        end
        @test apply_boundary!([4., 2., 3., 8.]) == [1., 2., 3., 3.]
    end
    @testset "CFL・有界性・非線形な波形変形" begin
        for (boundary, nx) in ((:fixed, 81), (:periodic, 80))
            r = simulate(; boundary, nx)
            @test r.max_cfl <= 0.5 + 1e-14
            @test 1 - 1e-13 <= minimum(r.u) <= maximum(r.u) <= 2 + 1e-13
            # c=1で同じ最終時刻まで移した矩形との離散L1差。周期では左右をつなぐ。
            shifted = [
                0.5 <=
                (boundary == :periodic ? mod(x - r.t_final, 2.) : x - r.t_final) <=
                1.0 ? 2. : 1. for x in r.x
            ]
            @test r.dx * sum(abs.(r.u - shifted)) > 0.2
            @test maximum(r.u[findall(>(1.5), r.x)]) > 1.2
        end
    end
end
@testset "N02 自作テスト" begin
    @testset "非対称場の40ステップ総和保存" begin
        u = [0.25, 1.5, 0.75, 2.0, 0.5, 1.0, 0.125]
        initial = sum(u); v = similar(u)
        for _ in 1:40
            nonlinear_upwind_step!(v, u, 0.025, 0.25; boundary=:periodic)
            @test isapprox(sum(v), initial; rtol=0, atol=1e-12*max(1,abs(initial)))
            u,v=v,u
        end
    end
    @testset "周期更新と循環移動の可換性" begin
        u=[0.25,1.5,0.75,2.,0.5,1.,0.125]; saved=copy(u)
        a=similar(u); b=similar(u)
        nonlinear_upwind_step!(a,u,0.025,0.25;boundary=:periodic)
        nonlinear_upwind_step!(b,circshift(u,3),0.025,0.25;boundary=:periodic)
        @test b ≈ circshift(a,3) atol=32eps() rtol=0
        @test u == saved
    end
end
