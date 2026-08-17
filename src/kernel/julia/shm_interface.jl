module SHMInterface

using Printf

const LIB_SHM_BRIDGE = "./shm_julia_bridge.so"

struct SHMHeader
	write_index::UInt64
	last_updated_epoch_ns::UInt64
	active_node_count::UInt32
	state_flags::UInt32
	mean_ricci_curvature::Float64
	re_lambda_max::Float64
end

struct SHMContext
	attached::Bool
end

function attach_shm()
	status = ccall((:julia_shm_attach, LIB_SHM_BRIDGE), Int32, ())
	if status != 0
		error("[SHMInterface FATAL] Cannot attach to Cytoplasm IV. Code: $status")
	end
	return SHMContext(true)
end

function read_header(ctx::SHMContext)
	raw_hdr = zeros(UInt8, 256)
	ccall((:julia_shm_read_header_raw, LIB_SHM_BRIDGE), Cvoid, (Ptr{UInt8},), raw_hdr)

	write_index = reinterpret(UInt64, raw_hdr[1:8])[1]
	last_updated_epoch_ns = reinterpret(UInt64, raw_hdr[9:16])[1]
	active_node_count = reinterpret(UInt32, raw_hdr[17:20])[1]
	state_flags = reinterpret(UInt32, raw_hdr[21:24])[1]
	mean_ricci = reinterpret(Float64, raw_hdr[25:32])[1]
	re_lambda_max = reinterpret(Float64, raw_hdr[33:40])[1]

	return SHMHeader(write_index, last_updated_epoch_ns, active_node_count, state_flags, mean_ricci, re_lambda_max)
end

function read_timeseries(ctx::SHMContext, time_steps::Int = 120)
	out_matrix = zeros(Float64, 128, time_steps)
	steps = ccall((:julia_shm_read_timeseries, LIB_SHM_BRIDGE), Int32,
								(Cint, Ptr{Cdouble}) , time_steps, out_matrix)
	if steps == 0
		return Matrix{Float64}(undef, 0, 0)
	end 
	return copy(out_matrix[:, 1:steps])
end

function write_sindy_coefficients_and_reset(cts::SHMContext, coeffs::Vector{Float64})
	D = length(coeffs) >= 1 ? coeffs[1] : 0.0
	lambda = length(coeffs) >= 2 ? coeffs[2] : 0.0
	ccall((:julia_shm_write_sindy_coefficients, LIB_SHM_BRIDGE), Cvoid,
				(Cdouble, Cdouble), D, lambda)
end

function reset_tda_flag_and_mark_sindy(ctx::SHMContext)
	ccall((:julia_shm_reset_tda_flag_and_mark_sindy, LIB_SHM_BRIDGE), Cvoid, ())
end

end # module

