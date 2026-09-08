module SHMInterface

using Printf

const LIB_SHM_BRIDGE = "./shm_julia_bridge.so"

export SHMHeader,
			 SHMContext,
			 attach_shm,
			 detach_shm,
			 read_header,
			 read_graph_snapshots,
			 write_sindy_model,
			 reset_tda_flag_and_mark_sindy

struct SHMHeader
    write_index::UInt64
    last_updated_epoch_ns::UInt64
    active_node_count::UInt32
    state_flags::UInt32
    mean_ricci_curvature::Float64
    tda_h1_persistence::Float64
    tda_h2_persistence::Float64
    re_lambda_max::Float64
end

struct SHMContext
    attached::Bool
end

function check_attached(ctx::SHMContext)
	if !ctx.attached
		error("[SHMInterface] Cytoplasm IV is not attached.")
	end
end

function attach_shm()
    status = ccall((:julia_shm_attach, LIB_SHM_BRIDGE), Int32, ())
    if status != 0
        error("[SHMInterface FATAL] Cannot attach to Cytoplasm IV. Code: $status")
    end
    return SHMContext(true)
end

function detach_shm(ctx::SHMContext)
	if ctx.attached
		ccall((:julia_shm_detach, LIB_SHM_BRIDGE), Cvoid, ())
	end

	return nothing
end

function read_header(ctx::SHMContext)::SHMHeader
	check_attached(ctx)
	raw = Ref(SHMHeader(UInt64(0), UInt64(0), UInt32(0), UInt32(0), 0.0, 0.0, 0.0, 0.0))


	ccall((:julia_shm_read_header_raw, LIB_SHM_BRIDGE), Cvoid, (Ref{SHMHeader},), raw)

	return raw[]
end

function read_recent_events(ctx::SHMContext, max_events::Int)
	if max_events <= 0
		error("max_events must be > 0")
	end

	vectors = zeros(Float64, 128, max_events)
	nodes = zeros(UInt32, max_events)
	timestamps = zeros(UInt64, max_events)
	count = ccall((:julia_shm_read_recent_events, LIB_SHM_BRIDGE), Cint, (Cint, Ptr{Cdouble}, Ptr{UInt32}, Ptr{UInt64}), max_events, vectors, nodes, timestamps)

	if count <= 0
		return (vectors = zeros(Float64, 128, 0), nodes = UInt32[], timestamps = UInt64[])
	end

	n = Int(count)
	
	return (vectors = copy(vectors[:, 1:n]), nodes = copy(nodes[1:n]), timestamps = copy(timestamps[1:n]))
end

function read_adjacency(ctx::SHMContext, max_nodes::Int)
	A = zeros(Float64, max_nodes, max_nodes)
	active_nodes = ccall((:julia_shm_read_adjacency, LIB_SHM_BRIDGE), Cint, (Cint, Ptr{Cdouble}), max_nodes, A)

	return(A, max(Int(active_nodes), 0))
end

function reconstruct_snapshots(vectors::Matrix{Float64}, nodes::Vector{UInt32}, timestamps::Vector{UInt64}, node_count::Int, time_steps::Int)
	E = length(timestamps)

	if E == 0
		return (zeros(Float64, node_count, 128, time_steps), zeros(UInt64, time_steps), 0.0, falses(node_count, time_steps))
	end

	if (size(vectors, 2) != E || length(nodes) != E)
		error("Event dimensions do not match")
	end

	if time_steps < 3
		error("time_steps must be > 3")
	end

	order = sortperm(timestamps)
	timestamps = timestamps[order]
	nodes = nodes[order]
	vectors = vectors[:, order]
	t_min = timestamps[1]
	t_max = timestamps[end]

	if t_max <= t_min
		return(zeros(Float64, node_count, 128, time_steps), fill(t_min, time_steps), 0.0, falses(node_count, time_steps))
	end

	span_ns = Float64(t_max - t_min)
	dt = span_ns / Float64(time_steps - 1) / 1.0e9
	snapshot_times = Vector{UInt64}(undef, time_steps)

	for t in 1:time_steps
		alpha = Float64(t - 1) / Float64(time_steps - 1)
		snapshot_times[t] = t_min + UInt64(round(alpha * span_ns))
	end

	observed = zeros(Float64, node_count, 128, time_steps)
	has_observation = falses(node_count, time_steps)

	for e in 1:E
		node = Int(nodes[e]) + 1
		if !(1 <= node <= node_count)
			continue
		end

		alpha = Float64(timestamps[e] - t_min) / span_ns
		snapshot = clamp(round(Int, alpha * Float64(time_steps - 1)) + 1, 1, time_steps)
		observed[node, :, snapshot] .= vectors[:, e]
		has_observation[node, snapshot] = true
	end

	U = zeros(Float64, node_count, 128, time_steps)
	valid = falses(node_count, time_steps)
	current = zeros(Float64, node_count, 128)
	seen = falses(node_count)

	for t in 1:time_steps
		for node in 1: node_count
			if has_observation[node, t]
				current[node, :] .= observed[node, :, t]
				seen[node] = true
			end

			if seen[node]
				valid[node, t] = true
			end
		end

		U[:, :, t] .= current
	end

	return (U, snapshot_times, dt, valid)
end

function read_graph_snapshots(ctx::SHMContext, max_nodes::Int, time_steps::Int; events_per_snapshot::Int = 32)
	max_events = max(time_steps * events_per_snapshot, time_steps)
	events = read_recent_events(ctx, max_events)

	if isempty(events.timestamps)
		return (zeros(Float64, 0, 128, 0), zeros(Float64, 0, 0), 0.0, UInt64[], falses(0, 0))
	end

	A_full, active_nodes = read_adjacency(ctx, max_nodes)
	max_event_node = maximum(Int.(events.nodes)) + 1
	N = min(max(active_nodes, max_event_node), max_nodes)
	U, snapshot_times, dt, valid = reconstruct_snapshots(events.vectors, events.nodes, events.timestamps, N, time_steps)
	A = copy(A_full[1:N, 1:N])

	return (U, A, dt, snapshot_times, valid)
end

function write_sindy_model(ctx::SHMContext,Xi::Matrix{Float64}, residual::Float64, relative_residual::Float64, fit_timestamp_ns::UInt64)
	if size(Xi) != (5, 128)
		error("Xi must have size (5, 128), got $(size(Xi))")
	end

	c0 = Vector{Float64}(Xi[1, :])
	c1 = Vector{Float64}(Xi[2, :])
	c2 = Vector{Float64}(Xi[3, :])
	c3 = Vector{Float64}(Xi[4, :])
	diffusion = Vector{Float64}(Xi[5, :])

	active_term_mask = UInt32(0)

	for term in 1:5
		if any(abs.(Xi[term, :]) .> 1e-12)
			active_term_mask |= UInt32(1) << UInt32(term - 1)
		end
	end

	ccall((:julia_shm_write_sindy_model, LIB_SHM_BRIDGE), Cvoid, (Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Ptr{Cdouble}, Cdouble, Cdouble, UInt32, UInt64), c0, c1, c2, c3, diffusion, residual, relative_residual, active_term_mask, fit_timestamp_ns)

	return nothing
end

function reset_tda_flag_and_mark_sindy(ctx::SHMContext)
	ccall((:julia_shm_reset_tda_flag_and_mark_sindy, LIB_SHM_BRIDGE), Cvoid, ())

	return nothing
end

end #module

