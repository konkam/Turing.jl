using Stats, Distributions, Turing
using Gadfly

include("ASCIIPlot.jl")
import Gadfly.ElementOrFunction

# First add a method to the basic Gadfly.plot function for QQPair types (generated by Distributions.qqbuild())
Gadfly.plot(qq::QQPair, elements::ElementOrFunction...) = Gadfly.plot(x=qq.qx, y=qq.qy, Geom.point, Theme(highlight_width=0px), elements...)

# Now some shorthand functions
qqplot(x, y, elements::ElementOrFunction...) = Gadfly.plot(qqbuild(x, y), elements...)
qqnorm(x, elements::ElementOrFunction...) = qqplot(Normal(), x, Guide.xlabel("Theoretical Normal quantiles"), Guide.ylabel("Observed quantiles"), elements...)

NSamples = 30000

@model gdemo2(x, bkstep) = begin
    if bkstep == false
        # Forward Sample
        s ~ InverseGamma(2,3)
        m ~ Normal(0,sqrt(s))
        y ~ MvNormal([m; m], [sqrt(s) 0; 0 sqrt(s)])
    elseif bkstep == true
        # Backward Step 1: theta ~ theta | x
        s ~ InverseGamma(2,3)
        m ~ Normal(0,sqrt(s))
        x ~ MvNormal([m; m], [sqrt(s) 0; 0 sqrt(s)])
        # Backward Step 2: x ~ x | theta
        y ~ MvNormal([m; m], [sqrt(s) 0; 0 sqrt(s)])
    end
    return s, m, y
end

fw = PG(20, NSamples)
# bk = Gibbs(10, PG(10,10, :s, :y), HMC(1, 0.25, 5, :m));
bk = PG(20,50);

s = sample(gdemo2([1.5, 2], false), fw);
describe(s)

N = div(NSamples, 50)

x = [s[:y][1]...]
s_bk = Array{Turing.Chain}(N)

for i = 1:N
    s_bk[i] = sample(gdemo2(x, true), bk);
    x = [s_bk[i][:y][end]...];
end

s2 = vcat(s_bk...);
describe(s2)


qqplot(s[:m], s2[:m])
qqplot(s[:s], s2[:s])

qqs = qqbuild(s[:s], s2[:s])
println("QQ plot for s:")
show(scatterplot(qqs.qx, qqs.qy))

println("QQ plot for s (removing last 50 quantiles):")
show(scatterplot(qqs.qx[51:end-50], qqs.qy[51:end-50]))

qqm = qqbuild(s[:m], s2[:m])
println("QQ plot for m:")
show(scatterplot(qqm.qx, qqm.qy))

println("QQ plot for m (removing first and last 50 quantiles):")
show(scatterplot(qqm.qx[51:end-50], qqm.qy[51:end-50]))
