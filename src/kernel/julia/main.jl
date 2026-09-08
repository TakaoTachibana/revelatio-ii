using Pkg

Pkg.activate(@__DIR__)

required_pkgs = ["LinearAlgebra", "Statistics", "Printf", "HTTP", "JSON3"]

for pkg in required_pkgs
	if !haskey(Pkg.project().dependencies, pkg)
		println("[Julia Setup] Installing missing package: $pkg...")
		Pkg.add(pkg)
	end
end

using Printf, HTTP, JSON3

include("shm_interface.jl")
include("sindy_pde.jl")

using .SHMInterface
using .SINDyPDE

const GATEWAY_URL = "http://localhost:5000/api/v1/topology/event"
const MAX_NODES = 256
const TIME_STEPS = 120
const EVENTS_PER_SNAPSHOT = 32

function identify_model(ctx::SHMContext)
	U, A, dt, snapshot_times, valid = SHMInterface.read_graph_snapshots(ctx, MAX_NODES, TIME_STEPS; events_per_snapshot=EVENTS_PER_SNAPSHOT)

	if isempty(U)
		println("[SINDy] No events available.")

		return nothing
	end

	N, D, T = size(U)

	if N < 2
		println("[SINDy] Need at least 2 nodes.")

		return nothing
	end

	if T < 5
		println("[SINDy] Need at least 5 snapshots.")

		return nothing
	end

	if !isfinite(dt) || dt <= 0.0
		println("[SINDy] Invalid dt: ", dt)

		return nothing
	end

	valid_count = count(valid)

	println("[SINDy] snapshots=", T, " nodes=", N, " features=", D, " dt=", dt, " valid=", valid_count)

	if sum(abs,A) <= sqrt(eps(Float64))
		println("[SINDy Warning] " * "Adjacency is empty. " * "Diffusion term will not be indentifiable.")
	end

	result = SINDyPDE.fit_graph_sindy_pde(U, A, dt; lambda=0.05, max_iter=15, valid_mask=valid)

	println("[SINDy] Equation: ", result.equation_str)
	@printf("[SINDy] RMSE: %.8f\n", result.residual)
	@printf("[SINDy] Relative residual: %.8f\n", result.relative_residual)
	println("[SINDy] Active terms: ", join(result.active_terms, ", "))

	fit_timestamp_ns = UInt64(round(time() * 1.0e9))

	SHMInterface.write_sindy_model(ctx, result.coefficients, result.residual, result.relative_residual, fit_timestamp_ns)

	println("[SINDy] Model written to SHM.")

	return result
end

function send_gateway_event(hdr::SHMHeader, result::SINDyResult)
	payload = (calculatedAtNs = round(Int64, time() * 1.0e9),
						 reLambdaMax = Float64(hdr.re_lambda_max),
						 meanRicciCurvature = Float64(hdr.mean_ricci_curvature),
						 tdaH1Persistence = Float64(hdr.tda_h1_persistence),
						 tdaH2Persistence = Float64(hdr.tda_h2_persistence),
						 sindyResidual = Float64(result.residual),
						 stateFlags = UInt32(hdr.state_flags),
						 equation = result.equation_str)

	@async begin
		try
			HTTP.post(GATEWAY_URL,["Content-Type" => "application/json"],
								JSON3.write(payload);
								connect_timeout=1,
								request_timeout=1)

			println("[Gateway] Event dispatched.")
		catch err
			println("[Gateway Warning] ", err)
		end
	end
end

function main()
	println("=== REVELATIO II Graph / Vector SINDy-PDE ===")
	ctx = SHMInterface.attach_shm()
	println("[Julia] Attched to Cytoplasm IV.")

	last_run_time = 0.0

	try
		while true
			hdr = SHMInterface.read_header(ctx)
			current_time = time()
			is_tda_triggered = (hdr.state_flags & UInt32(0x08)) != 0
			is_critical = (hdr.state_flags & UInt32(0x04)) != 0
			is_timeout = (current_time - last_run_time) > 10.0

			if(is_tda_triggered || is_critical || is_timeout)
				println()
				println("[SINDy] Re-identifying governing equation...")

				try
					result = identify_model(ctx)

					if result !== nothing
						send_gateway_event(hdr, result)
						SHMInterface.reset_tda_flag_and_mark_sindy(ctx)
						last_run_time = current_time
					end
				catch err
					println("[SINDy Error]", err)
					showerror(stderr, err)
					println()
				end
			end

			sleep(0.1)
		end
	finally
		SHMInterface.detach_shm(ctx)
	end
end

main()


	




