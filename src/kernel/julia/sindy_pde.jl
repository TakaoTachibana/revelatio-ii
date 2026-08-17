module SINDyPDE

using LinearAlgebra
using Statistics
using Printf

struct SINDyResult
	equation_str::String
	coefficients::Vector{Float64}
	residual::Float64
end

function fit_sindy_pde(U::Matrix{Float64})
	dim, T = size(U)
	if T < 10
		return SINDyResult("delu/delt = 0", [0.0, 0.0, 0.0], 0.0)
	end
	dt = 0.1
	dU_dt = (U[:, 2:end] .- U[:, 1:end - 1]) ./ dt
	
	Laplacian_U = zeros(Float64, dim, T - 1)
	for t in 1:T - 1
		u_t = U[:, t]
		lap = circshift(u_t, 1) .+ circshift(u_t, -1) .- 2.0 .* u_t
		Laplacian_U[:, t] = lap
	end

	u_vec = vec(U[:, 1:end - 1])
	lap_vec = vec(Laplacian_U)
	u_cubic_vec = u_vec .^ 3
	du_vec = vec(dU_dt)

	Theta = [lap_vec u_vec u_cubic_vec]
	Xi = Theta \ du_vec

	for iter in 1:3
		small_inds = abs.(Xi) .< 0.01
		Xi[small_inds] .= 0.0
		for i in 1:size(Theta, 2)
			if !small_inds[i]
				Xi[i] = Theta[:, i] \ du_vec
			end
		end
	end

	D_coeff = Xi[1]
	lambda_coeff = Xi[2]
	cubic_coeff = Xi[3]

	res_val = norm(Theta * Xi .- du_vec) / sqrt(length(du_vec))
	eq_str = @sprintf("delu/delt = %.4fdel^2u + %.4fu %+.4fu^3", D_coeff, lambda_coeff, cubic_coeff)

	return SINDyResult(eq_str, [D_coeff, lambda_coeff, cubic_coeff], res_val)
end

end # module

