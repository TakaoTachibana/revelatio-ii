module SINDyPDE

using LinearAlgebra
using Statistics
using Printf

export SINDyResult,
	fit_graph_sindy_pde,
	graph_laplacian,
	evaluate_rhs

const TERM_NAMES = ["1", "U", "U^2", "U^3", "-L*U"]

struct SINDyResult
	equation_str::String

	coefficients::Matrix{Float64}
	residual::Float64
	relative_residual::Float64

	active_terms::Vector{String}
	feature_count::Int
	snapshot_count::Int
	node_count::Int

	dt::Float64
end

function graph_laplacian(A::Matrix{Float64})
	N, M = size(A)

	if N != M
		throw(DimensionMismatch("Adjacency matrix must be square."))
	end

	A64 = Matrix{Float64}(A)
	A64 .= 0.5 .* (A64 .+ A64')

	for i in 1:N
		A64[i, i] = 0.0
	end

	degree = vec(sum(A64, dims=2))

	return Matrix(Diagonal(degree)) - A64
end

function time_derivative(U::Array{Float64, 3}, dt::Float64)
	N, D, T = size(U)

	if T < 3
		error("At least 3 snapshot required")
	end

	if !isfinite(dt) || dt <= 0.0
		error("dt must be positive")
	end

	Udot = zeros(Float64, N, D, T - 2)

	for t in 2:T - 1
		Udot[:, :, t - 1] .= (U[:, :, t + 1] .- U[:, :, t - 1]) ./ (2.0 * dt)
	end

	return Udot
end



function graph_diffusion(U::Array{Float64, 3}, L::Matrix{Float64})
	N, D, T = size(U)

	if size(L, 1) != N
		throw(DimensionMismatch("Graph size does not match U node count."))
	end

	LU = zeros(Float64, N, D, T)

	for t in 1:T
		LU[:, :, t] .= L * U[:, :, t]
	end

	return LU 
end

function build_library(u::Vector{Float64}, lu::Vector{Float64})
	if length(u) != length(lu)
		error("u and lu length mismatch")
	end

	return hcat(ones(Float64, length(u)), u, u .^ 2, u .^ 3, -lu)
end

function normalize_library(Theta::Matrix{Float64})
	ThetaN = copy(Theta)
	scales = ones(Float64, size(Theta, 2))

	for j in axes(Theta, 2)
		s = norm(Theta[:, j])
		if s > sqrt(eps(Float64))
			ThetaN[:, j] ./= s
			scales[j] = s
		end
	end

	return (ThetaN, scales)
end

function stlsq(Theta::Matrix{Float64}, y::Vector{Float64}; lambda::Float64 = 0.05, max_iter::Int = 15)
	xi = Theta \ y

	for _ in 1:max_iter
		old_xi = copy(xi)
		active = abs.(xi) .>= lambda

		if !any(active)
			xi .= 0.0
			break
		end

		new_xi = zeros(Float64, length(xi))
		new_xi[active] .= Theta[:, active] \ y
		xi = new_xi

		if norm(xi .- old_xi) <= 1e-10 * max(norm(old_xi), 1.0)
			break
		end
	end

	return xi
end

function format_equation(Xi::Matrix{Float64})
	c0 = median(Xi[1, :])
	c1 = median(Xi[2, :])
	c2 = median(Xi[3, :])
	c3 = median(Xi[4, :])
	diffusion = median(Xi[5, :])

	return @sprintf("delu/delt = %.4g %+.5gu %+.4gu^2 %+4gu^3 - %.4g L u", c0, c1, c2, c3, diffusion)
end

function fit_graph_sindy_pde(U::Array{Float64, 3}, A::AbstractMatrix{<:Real},dt::Float64; lambda::Float64 = 0.05, max_iter::Int = 15, valid_mask::Union{Nothing, BitMatrix} = nothing)
	N, D, T = size(U)

	if size(A) != (N, N)
		throw(DimensionMismatch("A must have size ($N, $N)"))
	end

	if T < 5
		error("At least 5 snapshots required")
	end

	if valid_mask !== nothing && size(valid_mask) != (N, T)
		throw(DimensionMismatch("valid must have size ($N, $T)"))
	end

	L = graph_laplacian(A)
	Udot = time_derivative(U, dt)
	LU_all = graph_diffusion(U, L)
	U_mid = U[:, :, 2:T - 1]
	LU_mid = LU_all[:, :, 2:T-1]
	derivative_valid = if valid_mask === nothing
		trues(N, T - 2)
	else
		valid_mask[:, 1:T - 2] .& valid_mask[:, 2:T - 1] .& valid_mask[:, 3:T]
	end
	Xi = zeros(Float64, 5, D)
	total_squared_error = 0.0
	total_target_energy = 0.0
	total_samples = 0

	for d in 1:D
		u = vec(U_mid[:, d, :])
		lu = vec(LU_mid[:, d, :])
		y = vec(Udot[:, d, :])
		valid = vec(derivative_valid)
		u = u[valid]
		lu = lu[valid]
		y = y[valid]

		if length(y) < 20
			continue
		end

		Theta = build_library(u, lu)
		ThetaN, scales = normalize_library(Theta)
		xi_normalized = stlsq(ThetaN, y; lambda=lambda, max_iter=max_iter)
		xi = xi_normalized ./ scales
		Xi[:, d] .= xi
		prediction = Theta * xi
		error_vector = prediction .- y
		total_squared_error += sum(abs2, error_vector)
		total_target_energy += sum(abs2, y)
		total_samples += length(y)
	end

	if total_samples == 0
		error("No valid SINDy samples")
	end

	residual = sqrt(total_squared_error / total_samples)
	relative_residual = sqrt(total_squared_error / max(total_target_energy, eps(Float64)))
	active_terms = String[]

	for term in 1:5
		if any(abs.(Xi[term, :]) .> lambda)
			push!(active_terms, TERM_NAMES[term])
		end
	end

	equation = format_equation(Xi)

	return SINDyResult(equation, Xi, residual, relative_residual, active_terms, D, T, N, dt)
end

function evaluate_rhs(result::SINDyResult, U::Matrix{Float64}, A::AbstractMatrix{<:Real})
	N, D = size(U)

	if D != result.feature_count
		throw(DimensionMismatch("Feature dimension mismatch"))
	end

	L = graph_laplacian(A)
	LU = L * U
	rhs = zeros(Float64, N, D)

	for d in 1:D
		c0 = result.coefficients[1, d]
		c1 = result.coefficients[2, d]
		c2 = result.coefficients[3, d]
		c3 = result.coefficients[4, d]
		diffusion = result.coefficients[5, d]

		rhs[:, d] .= c1 .* U[:, d] .+ c2 .* U[:, d] .+ c3 .* U[:, d] .- diffusion .* LU[:, d]
	end

	return rhs
end

end #module

