using Random
using LinearAlgebra
using Statistics

include("../src/kernel/julia/sindy_pde.jl")

using .SINDyPDE

Random.seed!(42)

N = 12
D = 16
T = 600
dt = 0.002

A = zeros(Float64, N, N)

for i in 1:N
	j = i == N ? 1 : i + 1
	A[i, j] = 1.0
	A[j, i] = 1.0
end

L = SINDyPDE.graph_laplacian(A)

C0_TRUE = 0.0
C1_TRUE = 0.25
C2_TRUE = 0.0
C3_TRUE = -0.10
D_TRUE = 0.08

U = zeros(Float64, N, D, T)
U[:, :, 1] .= 0.5 .* randn(N, D)

for t in 1:T - 1
	current = U[:, :, t]
	LU = L * current
	rhs = C0_TRUE .+ C1_TRUE .* current .+ C2_TRUE.* current .^ 2 .+ C3_TRUE .* current .^ 3 .- D_TRUE .* LU
	U[:, :, t + 1] .= current .+ dt .* rhs
end

result = SINDyPDE.fit_graph_sindy_pde(U, A, dt; lambda=1e-6, max_iter=20)
Xi = result.coefficients
c0_est = median(Xi[1, :])
c1_est = median(Xi[2, :])
c2_est = median(Xi[3, :])
c3_est = median(Xi[4, :])
d_est = median(Xi[5, :])

println()
println("=== Graph SINDy-PDE synthetic test ===")
println("c0 true = ", C0_TRUE, " estimated = ", c0_est)
println("c1 true = ", C1_TRUE, " estimated = ", c1_est)
println("c2 true = ", C2_TRUE, " estimated = ", c2_est)
println("c3 true = ", C3_TRUE, " estimated = ", c3_est)
println("D  true = ", D_TRUE, " estimated = ", d_est)
println("RMSE = ", result.residual)
println("Relative residual = ", result.relative_residual)
println("Active terms = ", result.active_terms)

@assert abs(c0_est - C0_TRUE) < 0.03
@assert abs(c1_est - C1_TRUE) < 0.03
@assert abs(c2_est - C2_TRUE) < 0.03
@assert abs(c3_est - C3_TRUE) < 0.03
@assert abs(d_est - D_TRUE) < 0.03
@assert result.relative_residual < 0.10

println()
println("PASS: governing Graph PDE recovered.")

