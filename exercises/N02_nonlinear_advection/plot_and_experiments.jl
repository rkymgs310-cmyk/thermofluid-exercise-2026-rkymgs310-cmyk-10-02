# Standard five-time plots, N01 comparison and optional CFL experiment.
using Plots, TOML, Test
include("run.jl")
include("../N01_linear_advection/run.jl")
const N=N02NonlinearAdvection
N.main()
times=[0.,.25,.5,.75,1.]
for (bc,nx,name) in ((:fixed,81,"fixed-boundary.png"),(:periodic,80,"periodic.png"))
    final=N.simulate(;boundary=bc,nx); p=plot(;xlabel="x",ylabel="u",title="Burgers: $bc",legend=:topleft)
    for (k,t) in enumerate(times)
        u=k==1 ? final.u0 : N.simulate(;boundary=bc,nx,t_final=t).u
        x=bc==:periodic ? vcat(final.x,2.) : final.x
        y=bc==:periodic ? vcat(u,u[1]) : u
        plot!(p,x,y;color=palette(:viridis,5)[k],label=k==1 ? "Initial (t=0)" : k==5 ? "Final (t=1)" : "t=$t",linewidth=2)
    end
    savefig(p,joinpath(@__DIR__,"results",name))
end
out=joinpath(@__DIR__,"../../scratch/N02-comparison");mkpath(out)
fixed=N.simulate(); linear=N01LinearAdvection.simulate(;scheme=:upwind,t_final=1.)
p=plot(fixed.x,fixed.u0;label="Initial",linestyle=:dot,color=:gray,xlabel="x",ylabel="u",title="Same grid, t=1, requested CFL=0.5")
plot!(p,linear.x,linear.u;label="N01 c=1",linewidth=2)
plot!(p,fixed.x,fixed.u;label="N02 Burgers",linewidth=2)
savefig(p,joinpath(out,"linear-nonlinear.png"))
for cfl in (.5,2.)
    dir=joinpath(@__DIR__,"../../scratch/N02-stability",string(cfl))
    try
        result=N.main(;cfl,t_final=.1,output_dir=dir)
        println("optional CFL=$cfl finite max CFL=$(result.fixed.max_cfl) range=$(extrema(result.fixed.u))")
    catch e
        println("optional CFL=$cfl stopped: ",sprint(showerror,e))
    end
end
