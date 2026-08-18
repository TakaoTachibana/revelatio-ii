# REVELATIO II Phase 2-A: R Analaytics Kernel
# 128D Manifold Ricci Curvature & TDA Persistence Disruption Engine

suppressPackageStartupMessages({
	library(TDA)
	library(igraph)
	library(matrixStats)
})

# Load C Bridge
dyn.load("shm_r_bridge.so")

attach_shm <- function() {
	res <- .C("r_shm_attach", status = integer(1))
	if (res$status != 0) {
		stop(paste("[R-Kernel FATAL] Cannot attach to Cytoplasm IV. Code:", res$status))
	}
	cat("[R-Kernel] Attached to Cytoplasm IV Shared Memory (512MB)\n")
}

read_vectors <- function(sample_count = 256) {
	out_mat <- numeric(sample_count * 128)
	out_ts <- numeric(sample_count)
	res <- .C("r_shm_read_recent_vectors",
						sample_count = as.integer(sample_count),
						out_matrix = as.double(out_mat),
						out_timestamps = as.double(out_ts))

	mat <- matrix(res$out_matrix, nrow = sample_count, ncol = 128, byrow = TRUE)
	return(list(matrix = mat, timestamps = res$out_timestamps))
}

read_adjacency <- function() {
	out_adj <- numeric(256 * 256)
	active_n <- integer(1)
	res <- .C("r_shm_read_adjacency_matrix",
						out_adj_256x256 = as.double(out_adj),
						active_nodes = as.integer(active_n))

	adj_mat <- matrix(res$out_adj_256x256, nrow = 256, ncol = 256, byrow = TRUE)
	return(list(adj = adj_mat, active_nodes = res$active_nodes))

}

compute_forman_ricci <- function(adj_matrix, active_nodes) {
	if (active_nodes < 3) {
		return (0.0)
	}

	sub_adj <- adj_matrix[1:active_nodes, 1:active_nodes]

	max_w <- max(sub_adj)
	if (max_w <= 0) {
		return (0.0)
	}

	norm_adj <- sub_adj / max_w
	deg <- rowSums(norm_adj)

	edges <- which(norm_adj > 0, arr.ind = TRUE)
	edges <- edges[edges[, 1] < edges[, 2], , drop = FALSE]

	if (nrow(edges) == 0) {
		return (0.0)
	}

	tri_mat <- norm_adj %*% norm_adj
	ricci_sum <- 0
	valid_edges <- 0

	for (e in 1:nrow(edges)) {
		u <- edges[e, 1]
		v <- edges[e, 2]

		deg_u <- max(deg[u], 1e-5)
		deg_v <- max(deg[v], 1e-5)
		deg_sum <- deg_u + deg_v
		triangles_uv <- tri_mat[u, v]

		raw_r <- 4.0 - deg_sum + 3.0 * triangles_uv
		norm_r <- (raw_r / deg_sum) - 0.111

		ricci_sum <- ricci_sum + norm_r
		valid_edges <- valid_edges + 1
	}

	if (valid_edges == 0) {
		return (0.0)
	}
	mean_ricci <- ricci_sum / valid_edges
	return (mean_ricci)
}

compute_tda_persistence <- function(vec_matrix) {
	clean_mat <- vec_matrix[!duplicated(vec_matrix), ]
	if (nrow(clean_mat) < 15) {
		return (list(h1 = 0.0, h2 = 0.0))
	}

	svd_res <- prcomp(clean_mat, rank. = 4, scale. = FALSE)
	low_dim_mat <- svd_res$x

	dist_max <- as.matrix(dist(low_dim_mat))
	max_scale <- quantile(dist_max, 0.75)

	if (max_scale <= 0) {
		return (list(h1 = 0.0, h2 = 0.0))
	}

	Diag <- tryCatch({
		ripsDiag(X = low_dim_mat, maxdimension = 2, maxscale = max_scale, library = "GUDHI")
	}, error = function(e) {
		return (NULL)
	})

	if (is.null(Diag) || is.null(Diag$diagram)) {
		return (list(h1 = 0.0, h2 = 0.0))
	}

	diag <- Diag$diagram
	h1_pers <- 0.0
	h2_pers <- 0.0

	h1_idx <- which(diag[, 1] == 1)
	if (length(h1_idx) > 0) {
		h1_pers <- max(diag[h1_idx, 3] - diag[h1_idx, 2])
	}

	h2_idx <- which(diag[, 1] == 2)
	if (length(h2_idx) > 0) {
		h2_pers <- max(diag[h2_idx, 3] - diag[h2_idx, 2])
	}

	return (list(h1 = h1_pers, h2 = h2_pers))
}

main_loop <- function() {
	attach_shm()
	on.exit(.C("r_shm_detach"))

	cat("[R-Kernel] Starting Real-Time Sensing Loop (Interval: 2s) ...\n")

	repeat {
		vec_data <- read_vectors(sample_count = 128)
		adj_data <- read_adjacency()

		mean_ricci <- compute_forman_ricci(adj_data$adj, adj_data$active_nodes)
		tda_res <- compute_tda_persistence(vec_data$matrix)

		state_flags <- 0
		if (mean_ricci < -1.2) {
			state_flags <- bitwOr(state_flags, 2) # PERTURBED
		}
		if (mean_ricci < -2.0) {
			state_flags <- bitwOr(state_flags, 4) # CRITICAL
		}
		if (tda_res$h1 > 0.3 || tda_res$h2 > 0.2) {
			state_flags <- bitwOr(state_flags, 8) # TDA_DISRUPTION
		}

		.C("r_shm_update_metrics",
			 as.double(mean_ricci),
			 as.double(tda_res$h1),
			 as.double(tda_res$h2),
			 as.integer(state_flags))

		cat(sprintf("[R-Kernel Sensing] Mean Ricci: %6.2f | H1 Pers: %5.3f | H2 Pers: %5.3f | State Flags: 0x%02X\n",
								mean_ricci, tda_res$h1, tda_res$h2, state_flags))

		Sys.sleep(2.0)
	}
}

if (sys.nframe() == 0) {
	main_loop()
}

