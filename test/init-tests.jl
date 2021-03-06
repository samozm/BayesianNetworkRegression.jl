## Initial tests for BayesianNetworkRegression.jl on toy data

function symmetrize_matrices(X)
    X_new = Array{Array{Int8,2},1}(undef,0)
    for i in 1:size(X,1)
        B = convert(Matrix, reshape(X[i], 4, 4))
        push!(X_new,Symmetric(B))
    end
    X = X_new
end

## global seed
rng = Xoshiro(1234)

X = [[0, 1, 0, 1,
     1, 0, 1, 1,
     0, 1, 0, 0,
     0, 1, 0, 0],
    [0, 1, 1, 1,
     1, 0, 1, 1,
     1, 1, 0, 0,
     1, 1, 0, 0],
    [0, 0, 1, 0,
     0, 0, 1, 1,
     1, 1, 0, 0,
     0, 1, 0, 0],
    [0, 0, 1, 0,
     0, 0, 1, 1,
     1, 1, 0, 1,
     0, 1, 1, 0]]

Z = symmetrize_matrices(X)

y = ones(size(Z[1],1))*12 + rand(rng, Normal(0,2),size(Z[1],1))

η  = 1.01
ζ  = 1.0
ι  = 1.0
R  = 7
aΔ = 1.0
bΔ = 1.0
V = size(Z,1)
q = floor(Int,V*(V-1)/2)
n = size(Z,1)
ν = 10
total = 20

st1 = Table(τ² = Array{Float64,3}(undef,(total,1,1)), u = Array{Float64,3}(undef,(total,R,V)),
                  ξ = Array{Float64,3}(undef,(total,V,1)), γ = Array{Float64,3}(undef,(total,q,1)),
                  S = Array{Float64,3}(undef,(total,q,1)), θ = Array{Float64,3}(undef,(total,1,1)),
                  Δ = Array{Float64,3}(undef,(total,1,1)), M = Array{Float64,3}(undef,(total,R,R)),
                  μ = Array{Float64,3}(undef,(total,1,1)), λ = Array{Float64,3}(undef,(total,R,1)),
                  πᵥ= Array{Float64,3}(undef,(total,R,3)));

X_new = Array{Float64,2}(undef,n,q)
##X_new = rand(rng, Normal(0,2),n,q) ## test added thinking undef was causing float issues, but no

@testset "InitTests - Dimensions and initializations" begin
    tmprng = Xoshiro(100)
    @show X_new
    BayesianNetworkRegression.initialize_variables!(st1, X_new, Z, η, ζ, ι, R, aΔ, bΔ, ν,tmprng, V,true)

    @test size(X_new) == (n,q)
    @test size(st1.S[1,:,1]) == (q,)
    @test size(st1.πᵥ[1,:,:]) == (R,3)
    @test size(st1.λ[1,:,1]) == (R,)
    @test issubset(st1.ξ[1,:,1],[0,1])
    @test size(st1.M[1,:,:]) == (R,R)
    @test size(st1.u[1,:,:]) == (R,V)
    @test size(st1.γ[1,:,1]) == (q,)

    @test st1.S[1,:,1] ≈ [0.03598930544575977, 0.0603934986743537, 0.1764484862629309, 0.3632764655421976, 0.007526019822996736, 0.05200735141854831] rtol=1.0e-5
    @test st1.πᵥ[1,:,:] ≈ [ 0.626859  0.280666  0.0924745
    0.371267  0.157296  0.471437
    0.717476  0.232063  0.0504618
    0.791929  0.157269  0.0508017
    0.783576  0.09253   0.123894
    0.565146  0.172771  0.262082
    0.700685  0.210195  0.0891198] rtol=1.0e-5
    @test st1.λ[1,:,1] ≈ [0.0, -1.0, 0.0, 0.0, 0.0, 0.0, 0.0] rtol=1.0e-5
    @test st1.ξ[1,:,1] ≈ [1.0, 0.0, 0.0, 1.0] rtol=1.0e-5
    @test st1.u[1,:,:] ≈ [-1.87977    -2.07963     0.0534882  -0.523869
    -0.496949    0.727705    1.56318     0.675932
     0.92985    -0.0793574  -1.92791    -0.132813
    -0.0933149   2.34383    -0.115944    0.944412
     0.315965    0.918077    0.156086    0.848895
    -0.194196   -0.538818    2.06303    -0.823907
     0.869498   -1.05767    -0.328555   -1.71021] rtol=1.0e-5
    @test st1.M[1,:,:] ≈ [0.393213    0.0677387    -0.143539    0.117398   0.0183584  -0.0125626   0.0250371
    0.0677387   0.250744     -0.178058    0.2693     0.139946   -0.151376    0.000388039
   -0.143539   -0.178058      0.388073   -0.392038  -0.171502    0.243406   -0.0916206
    0.117398    0.2693       -0.392038    0.592995   0.246248   -0.304492    0.123414
    0.0183584   0.139946     -0.171502    0.246248   0.265738   -0.153965    0.0679314
   -0.0125626  -0.151376      0.243406   -0.304492  -0.153965    0.439245   -0.047125
    0.0250371   0.000388039  -0.0916206   0.123414   0.0679314  -0.047125    0.12465] rtol=1.0e-5   
    @test st1.γ[1,:,1] ≈ [0.23312150423633562, 1.2613526035435167, 0.7685963241905475, -0.2625875428286474, -0.5249776448407018, -1.244364438511821] rtol=1.0e-5
end


@testset "InitTests - Gibbs sampler" begin
    tmprng = Xoshiro(100)
    BayesianNetworkRegression.GibbsSample!(st1, 2, X_new, y, V, η, ζ, ι, R, aΔ, bΔ, ν, tmprng)

    @test st1.τ²[2,1,1] ≈  53.14255506411379 rtol=1.0e-5
    @test st1.ξ[2,:,1] ≈ [1.0, 1.0, 1.0, 0.0] rtol=1.0e-5
    @test st1.u[2,:,:] ≈ [0.671016    -0.406461   -0.642231  -0.0
    0.249684     0.135334   -0.284379   0.0
   -0.168423     0.262885    0.640464   0.0
   -0.00564053   0.269829   -0.325836  -0.0
   -0.604909     0.0318735  -0.702243   0.0
   -0.929387     0.385997    0.166951   0.0
    0.115952    -0.27374    -0.209991  -0.0] rtol=1.0e-5
    @test st1.γ[2,:,1] ≈ [-0.19152010859792637, 1.8434115313186552, 0.42601886947797807, 9.337415576916547, -0.09813317522307027, -0.8013663372916928] rtol=1.0e-5
    @test st1.θ[2,1,1] ≈ 1.3581265792710897 rtol=1.0e-5
    @test st1.Δ[2,1,1] ≈ 0.8134507774943599 rtol=1.0e-5
    @test st1.M[2,:,:] ≈ [0.273763     0.0353217   -0.079806    -0.00101323  -0.173149   -0.263986    0.1806
    0.0353217    0.0931685    0.0269158    0.00186593  -0.0431823  -0.0265039   0.0640589
   -0.079806     0.0269158    0.162169    -0.0305419   -0.0239427   0.0772602  -0.00861313
   -0.00101323   0.00186593  -0.0305419    0.0898826    0.0356746   0.016511   -0.00367373
   -0.173149    -0.0431823   -0.0239427    0.0356746    0.427098    0.3436     -0.153249
   -0.263986    -0.0265039    0.0772602    0.016511     0.3436      0.421775   -0.182341
    0.1806       0.0640589   -0.00861313  -0.00367373  -0.153249   -0.182341    0.264681] rtol=1.0e-5
    @test st1.μ[2,1,1] ≈ 2.2761175123978554 rtol=1.0e-5

    @test st1.S[2,:,1] ≈ [0.30879925978059203, 0.9482456351524313, 1.628003653986242, 1.797012446535061, 0.1020714178147614, 0.04758353071000775] rtol=1.0e-5
    @test st1.πᵥ[2,:,:] ≈ [0.443175  0.39275    0.164075
    0.14177   0.0530093  0.805221
    0.307544  0.374631   0.317825
    0.92838   0.0109714  0.0606483
    0.432819  0.510747   0.056434
    0.664529  0.169368   0.166103
    0.886855  0.0530086  0.0601366] rtol=1.0e-5
    @test st1.λ[2,:,1] ≈ [1.0, -1.0, 0.0, 0.0, 1.0, 0.0, 0.0] rtol=1.0e-5
end

@testset "InitTests - Deconstructed Gibbs sampler" begin
    n = size(X_new,1)
    rng = Xoshiro(123)

    BayesianNetworkRegression.update_τ²!(st1, 3, X_new, y, V, rng)
    @test st1.τ²[3,1,1] ≈  10.623553285374285 rtol=1.0e-5

    BayesianNetworkRegression.update_u_ξ!(st1, 3, V, rng)
    @test st1.ξ[3,:,1] ≈ [0.0, 1.0, 1.0, 1.0] rtol=1.0e-5
    @test st1.u[3,:,:] ≈ [0.0  -0.605982   0.0258551    0.594153
    0.0  -0.138483  -0.00601066   0.061628
   -0.0  -0.138767  -0.372018     0.277599
    0.0   0.194018  -0.353501     0.131301
   -0.0   0.236029   0.0952192   -0.480368
   -0.0   0.421805  -0.0441781   -0.738795
    0.0  -0.521303   0.133158     0.356793] rtol=1.0e-5

    BayesianNetworkRegression.update_γ!(st1, 3, X_new, y, n, rng)
    @test st1.γ[3,:,1] ≈ [-0.38486464238207996, 3.6088003414438874, 0.9960062396301632, 5.863077621691737, 0.03851040729191779, -0.8745235771172336] rtol=1.0e-5

    BayesianNetworkRegression.update_D!(st1, 3, V, rng)
    BayesianNetworkRegression.update_θ!(st1, 3, ζ, ι, V, rng)
    @test st1.θ[3,1,1] ≈ 0.8186122391370304 rtol=1.0e-5

    BayesianNetworkRegression.update_Δ!(st1, 3, aΔ, bΔ, rng)
    @test st1.Δ[3,1,1] ≈ 0.46313654579935853 rtol=1.0e-5

    BayesianNetworkRegression.update_M!(st1, 3, ν, V, rng)
    @test st1.M[3,:,:] ≈ [0.262548   -0.133862    0.0368896   -0.0101741  -0.0551614  -0.132834    0.0541826
    -0.133862    0.305542   -0.0508244   -0.1025     -0.0425931   0.0880569   0.0652346
     0.0368896  -0.0508244   0.168352     0.0434624  -0.0223446  -0.0971323   0.00388392
    -0.0101741  -0.1025      0.0434624    0.142135    0.0183438  -0.0288082  -0.0842067
    -0.0551614  -0.0425931  -0.0223446    0.0183438   0.152203    0.146052   -0.111897
    -0.132834    0.0880569  -0.0971323   -0.0288082   0.146052    0.343175   -0.151976
     0.0541826   0.0652346   0.00388392  -0.0842067  -0.111897   -0.151976    0.223258] rtol=1.0e-5

    BayesianNetworkRegression.update_μ!(st1, 3, X_new, y, n, rng)
    @test st1.μ[3,1,1] ≈ 5.767351224597342 rtol=1.0e-5

    BayesianNetworkRegression.update_Λ!(st1, 3, R, rng)
    @test st1.λ[3,:,1] ≈ [0.0, -1.0, -1.0, 0.0, 1.0, 0.0, 0.0] rtol=1.0e-5

    BayesianNetworkRegression.update_π!(st1, 3, η, R, rng)
    @test st1.πᵥ[3,:,:] ≈ [0.586798  0.196121    0.217081
    0.40628   0.00497569  0.588744
    0.293272  0.650475    0.0562529
    0.43479   0.215641    0.349569
    0.662981  0.219697    0.117321
    0.676868  0.286746    0.0363864
    0.784739  0.163413    0.0518482] rtol=1.0e-5
    @test st1.S[3,:,1] ≈ [0.2040844518417715, 1.5949727886526697, 0.10879433921685362, 4.433117160764325, 2.1726364676770786, 1.2583183196954393] rtol=1.0e-5
end