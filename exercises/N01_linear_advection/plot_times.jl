# 公式課題の5時刻表示を補う。提供済みの数値更新・描画関数は変更しない。
# 標準条件専用。run.jlの通常出力を生成後、このコマンドでPNGを5時刻表示に更新する。
if !isdefined(Main, :N01LinearAdvection)
    include(joinpath(@__DIR__, "run.jl"))
end
using Plots

function plot_standard_times(; output_dir = joinpath(@__DIR__, "results"))
    times = [0.0, 0.125, 0.250, 0.375, 0.5]
    final_results = map((:upwind, :centered)) do scheme
        snapshots = [N01LinearAdvection.simulate(; scheme, t_final = t) for t in times[2:end]]
        # 各時刻は標準dtの整数倍。同一刻みの途中の状態を再現する。
        for (t, result) in zip(times[2:end], snapshots)
            @assert isapprox(result.dt, 0.0125; atol = 100eps())
            @assert isapprox(result.steps * result.dt, t; atol = 100eps())
        end
        final = last(snapshots)
        colors = palette(scheme === :upwind ? :viridis : :plasma, length(times))
        title = scheme === :upwind ? "Upwind + Euler" : "Centered + Euler"
        figure = plot(; xlabel = "x", ylabel = "u", title, legend = :topleft)
        states = [final.u0, [result.u for result in snapshots]...]
        for (index, (t, u)) in enumerate(zip(times, states))
            label = index == 1 ? "Initial (t=0)" : index == length(times) ? "Final (t=0.5)" : "t=$t"
            plot!(figure, final.x, u; color = colors[index], label, linewidth = 2)
        end
        mkpath(output_dir)
        name = scheme === :upwind ? "upwind.png" : "centered-euler.png"
        savefig(figure, joinpath(output_dir, name))
        final
    end
    N01LinearAdvection.write_summary(output_dir, final_results...)
    println("N01の5時刻表示と診断値を保存しました: $(abspath(output_dir))")
    return final_results
end

if abspath(PROGRAM_FILE) == @__FILE__
    plot_standard_times()
end
