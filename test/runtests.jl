using Test,BayesianNetworkRegression,LinearAlgebra,Distributions
using CSV,DataFrames,StaticArrays,TypedTables,Random,Distributed

function symmetrize_matrices(X)
    X_new = Array{Array{Int8,2},1}(undef,0)
    for i in 1:size(X,1)
        B = convert(Matrix, reshape(X[i], 4, 4))
        push!(X_new,Symmetric(B))
    end
    X = X_new
end

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


y = ones(size(Z[1],1))*12 + rand(Normal(0,2),size(Z[1],1))


η  = 1.01
ζ  = 1.0
ι  = 1.0
R  = 5
aΔ = 0.0
bΔ = 0.0
V = size(Z,1)
q = floor(Int,V*(V-1)/2)
n = size(Z,1)
ν = 12
total = 20
tmprng = MersenneTwister(100)

st1 = Table(τ² = Array{Float64,3}(undef,(total,1,1)), u = Array{Float64,3}(undef,(total,R,V)),
                  ξ = Array{Float64,3}(undef,(total,V,1)), γ = Array{Float64,3}(undef,(total,q,1)),
                  S = Array{Float64,3}(undef,(total,q,1)), θ = Array{Float64,3}(undef,(total,1,1)),
                  Δ = Array{Float64,3}(undef,(total,1,1)), M = Array{Float64,3}(undef,(total,R,R)),
                  μ = Array{Float64,3}(undef,(total,1,1)), λ = Array{Float64,3}(undef,(total,R,1)),
                  πᵥ= Array{Float64,3}(undef,(total,R,3)))

X_new = Array{Float64,2}(undef,n,q)

@testset "InitTests - Dimensions" begin
    BayesianNetworkRegression.initialize_variables!(st1, X_new, Z, η, ζ, ι, R, aΔ, bΔ, ν,tmprng, V,true)

    @test size(X_new) == (n,q)
    @test size(st1.S[1,:,1]) == (q,)
    @test size(st1.πᵥ[1,:,:]) == (R,3)
    @test size(st1.λ[1,:,1]) == (R,)
    @test issubset(st1.ξ[1,:,1],[0,1])
    @test size(st1.M[1,:,:]) == (R,R)
    @test size(st1.u[1,:,:]) == (R,V)
    @test size(st1.γ[1,:,1]) == (q,)
end

@testset "Dimension tests" begin
    R  = 5
    V = 20
    nburn = 200
    nsamp = 200
    q = floor(Int,V*(V-1)/2)

    data_in = DataFrame(CSV.File(joinpath(@__DIR__, "data", "test1.csv")))

    X = Matrix(data_in[:,1:190])
    y = data_in[:,191]

    res1 = Fit!(X, y, R, nburn=nburn,nsamples=nsamp, V=V, aΔ=1.0, bΔ=1.0,ν=10 ,ι=1.0,ζ=1.0,x_transform=false,num_chains=1,in_seq=true,suppress_timer=true)

    result1 = res1.state
    
    @test size(result1.γ) == (nsamp+nburn,q,1)
    @test size(result1.ξ) == (nsamp+nburn,V,1)
    @test size(result1.u) == (nsamp+nburn,R,V)
end

@testset "Result tests - 1 chain" begin
    R  = 7
    V = 30
    nburn = 120000
    nsamp = 40000
    total = nburn+nsamp
    q = floor(Int,V*(V-1)/2)
    seed = 32

    #Random.seed!(seed)

    data_in = DataFrame(CSV.File(joinpath(@__DIR__, "data", "mu=1.6_n_microbes=22_out=XYs_pi=0.8_samplesize=100_simnum=1.csv")))
    edges_res = DataFrame(CSV.File(joinpath(@__DIR__,"data","R=7_mu=1.6_n_microbes=22_nu=10_out=edges_pi=0.8_samplesize=100_simnum=1.csv")))
    nodes_res = DataFrame(CSV.File(joinpath(@__DIR__,"data","R=7_mu=1.6_n_microbes=22_nu=10_out=nodes_pi=0.8_samplesize=100_simnum=1.csv")))

    X = Matrix(data_in[:,names(data_in,Not("y"))])
    y = SVector{size(X,1)}(data_in[:,:y])

    if V != convert(Int,(1 + sqrt(1 + 8*size(X,2)))/2)
        println("wrong V")
    end

    result2 = Fit!(X, y, R, nburn=nburn,nsamples=nsamp, V=V,ν=10,
               x_transform=false,num_chains=1,in_seq=true,seed=seed,full_results=false,suppress_timer=true)
    @show seed 

    γ_sorted = sort(result2.state.γ[nburn+1:total,:,:],dims=1)
    @show size(γ_sorted)
    lw = convert(Int64, round(nsamp * 0.025))
    hi = convert(Int64, round(nsamp * 0.975))
    
    ci_df = DataFrame(mean=mean(result2.state.γ[nburn+1:total,:,:],dims=1)[1,:])
    ci_df[:,"0.025"] = γ_sorted[lw,:,1]
    ci_df[:,"0.975"] = γ_sorted[hi,:,1]

    @test isapprox(mean(result2.state.γ[nburn+1:total,:,:],dims=1)[1,:], edges_res.mean,atol=0.5)
    @test isapprox(ci_df[:,"0.025"],edges_res[:,"0.025"],atol=0.5)
    @test isapprox(ci_df[:,"0.975"],edges_res[:,"0.975"],atol=0.5)
    @test isapprox(mean(result2.state.ξ[nburn+1:total,:,:],dims=1)[1,:],nodes_res[:,"Xi posterior"],atol=0.05)
end 


@testset "Result tests - parallel" begin
    addprocs(2)
    seed = 23

    @everywhere begin
        using BayesianNetworkRegression,CSV,DataFrames,StaticArrays
        using TypedTables,Random,LinearAlgebra,Distributions
    
        R = 7
        V = 30
        nburn = 120000
        nsamp = 40000
        total = nburn+nsamp
        q = floor(Int,V*(V-1)/2)
        seed = 23


        Random.seed!(seed)

        data_in = DataFrame(CSV.File(joinpath(@__DIR__, "data", "mu=1.6_n_microbes=8_out=XYs_pi=0.8_samplesize=100_simnum=1.csv")))

        X = Matrix(data_in[:,names(data_in,Not("y"))])
        y = SVector{size(X,1)}(data_in[:,:y])
    end

    result3 = Fit!(X, y, R, nburn=nburn,nsamples=nsamp, V=V, ν=10,
               x_transform=false,num_chains=2,in_seq=false,seed=seed,suppress_timer=true)
    
    γ_sorted = sort(result3.state.γ[nburn+1:total,:,:],dims=1)
    lw = convert(Int64, round(nsamp * 0.025))
    hi = convert(Int64, round(nsamp * 0.975))
    
    ci_df = DataFrame(mean=mean(result3.state.γ[nburn+1:total,:,:],dims=1)[1,:])
    ci_df[:,"0.025"] = γ_sorted[lw,:,1]
    ci_df[:,"0.975"] = γ_sorted[hi,:,1]

    edges_res = DataFrame(CSV.File(joinpath(@__DIR__,"data","R=7_mu=1.6_n_microbes=8_nu=10_out=edges_pi=0.8_samplesize=100_simnum=1.csv")))
    nodes_res = DataFrame(CSV.File(joinpath(@__DIR__,"data","R=7_mu=1.6_n_microbes=8_nu=10_out=nodes_pi=0.8_samplesize=100_simnum=1.csv")))

    @test isapprox(mean(result3.state.γ[nburn+1:total,:,:],dims=1)[1,:], edges_res.mean,atol=0.5)
    @test isapprox(ci_df[:,"0.025"],edges_res[:,"0.025"],atol=0.5)
    @test isapprox(ci_df[:,"0.975"],edges_res[:,"0.975"],atol=0.5)
    @test isapprox(mean(result3.state.ξ[nburn+1:total,:,:],dims=1)[1,:],nodes_res[:,"Xi posterior"],atol=0.05)
end