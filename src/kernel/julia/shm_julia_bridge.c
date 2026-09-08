#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <stddef.h>
#include "../../../include/cytoplasm_v4.h"

static CytoplasmV4 *g_cytoplasm = NULL;

typedef struct {
	uint64_t write_index;
	uint64_t last_updated_epoch_ns;
	uint32_t active_node_count;
	uint32_t state_flags;
	double mean_ricci_curvature;
	double tda_h1_persistence;
	double tda_h2_persistence;
	double re_lambda_max;
} JuliaHeaderBuffer;

int julia_shm_attach(void) {
	if (g_cytoplasm != NULL) {
		return 0;
	}

	int shmid = shmget((key_t)CYTOPLASM_V4_IPC_KEY, sizeof(CytoplasmV4), 0666);
	if (shmid < 0) {
		return -1;
	}

	void *shm_ptr = shmat(shmid, NULL, 0);
	if (shm_ptr == (void *)-1) {
		return -2;
	}

	g_cytoplasm = (CytoplasmV4 *)shm_ptr;
	return 0;
}

void julia_shm_read_header_raw(void *out_hdr) {
	if (g_cytoplasm == NULL || out_hdr == NULL) {
		return;
	}

	JuliaHeaderBuffer *buf = (JuliaHeaderBuffer *)out_hdr;
	buf->write_index = __atomic_load_n(&g_cytoplasm->header.write_index, __ATOMIC_ACQUIRE);
	buf->last_updated_epoch_ns = __atomic_load_n(&g_cytoplasm->header.last_updated_epoch_ns, __ATOMIC_ACQUIRE);
	buf->active_node_count = __atomic_load_n(&g_cytoplasm->header.active_node_count, __ATOMIC_ACQUIRE);
	buf->state_flags = __atomic_load_n(&g_cytoplasm->header.state_flags, __ATOMIC_ACQUIRE);
	buf->mean_ricci_curvature = g_cytoplasm->header.mean_ricci_curvature;
	buf->tda_h1_persistence = g_cytoplasm->coefficients.tda_h1_persistence;
	buf->tda_h2_persistence = g_cytoplasm->coefficients.tda_h2_persistence;
	buf->re_lambda_max = g_cytoplasm->header.re_lambda_max;
}

int julia_shm_read_timeseries(int time_steps, double *out_matrix) {
	if (g_cytoplasm == NULL || out_matrix == NULL || time_steps <= 0) {
		return 0;
	}

	uint64_t write_index = __atomic_load_n(&g_cytoplasm->header.write_index, __ATOMIC_ACQUIRE);

	if (write_index == 0) {
		return 0;
	}

	uint64_t committed_count = write_index;
	uint64_t available = committed_count;

	if (available > VECTOR_RING_CAPACITY) {
		available = VECTOR_RING_CAPACITY;
	}

	if (available > (uint64_t)time_steps) {
		available = (uint64_t)time_steps;
	}

	uint64_t start = committed_count - available;
	int output_count = 0;

	for (uint64_t logical_index = start; logical_index < committed_count; logical_index++) {
		uint32_t slot_index = (uint32_t)(logical_index % VECTOR_RING_CAPACITY);
		const VectorSlot *src = &g_cytoplasm->vectors[slot_index];

		uint64_t slot_id = __atomic_load_n(&src->slot_id, __ATOMIC_ACQUIRE);

		if (slot_id != logical_index) {
			continue;
		}

		if (src->timestamp_ns == 0) {
			continue;
		}
		
		for (int d = 0; d < VECTOR_DIM; d++) {
			out_matrix[d + output_count * VECTOR_DIM] = (double)src->values[d];
		}
		output_count++;
	}
	return output_count;
}

void julia_shm_write_sindy_coefficients(double diffusion_D, double reaction_lambda) {
	if (g_cytoplasm == NULL) {
		return;
	}

	g_cytoplasm->header.re_lambda_max = reaction_lambda;

	for (int d = 0; d < VECTOR_DIM; d++) {
		g_cytoplasm->coefficients.diffusion_tensor[d] = diffusion_D;
		g_cytoplasm->coefficients.c1_diag[d] = reaction_lambda;
	}
}

void julia_shm_reset_tda_flag_and_mark_sindy(void) {
	if (g_cytoplasm == NULL) {
		return;
	}
	uint32_t clear_mask = (uint32_t)(STATE_FLAG_CRITICAL | STATE_FLAG_TDA_DISRUPTION | STATE_FLAG_PERTURBED);
	__atomic_fetch_and(&g_cytoplasm->header.state_flags, ~clear_mask, __ATOMIC_ACQ_REL);
}

void julia_shm_detach(void) {
	if (g_cytoplasm != NULL) {
		shmdt((void *)g_cytoplasm);
		g_cytoplasm = NULL;
	}
}

int julia_shm_read_recent_events(int max_events, double *out_vectors, uint32_t *out_nodes, uint64_t *out_timestamps) {
	if (g_cytoplasm == NULL || max_events <= 0 || out_vectors == NULL || out_nodes == NULL || out_timestamps == NULL) {
		return 0;
	}

	uint64_t write_index = __atomic_load_n(&g_cytoplasm->header.write_index, __ATOMIC_ACQUIRE);

	if (write_index == 0) {
		return 0;
	}

	uint64_t committed_count = write_index;
	uint64_t available = committed_count;

	if (available > VECTOR_RING_CAPACITY) {
		available = VECTOR_RING_CAPACITY;
	}

	if (available > (uint64_t)max_events) {
		available = (uint64_t)max_events;
	}

	uint64_t start = committed_count - available;
	int output_count = 0;

	for (uint64_t logical_index = start; logical_index < committed_count; logical_index++) {
		uint32_t slot_index = (uint32_t)(logical_index % VECTOR_RING_CAPACITY);
		VectorSlot *slot = &g_cytoplasm->vectors[slot_index];

		uint64_t slot_id = __atomic_load_n(&slot->slot_id, __ATOMIC_ACQUIRE);

		if (slot_id != logical_index || slot->timestamp_ns == 0) {
			continue;
		}

		out_nodes[output_count] = slot->node_index;
		out_timestamps[output_count] = slot->timestamp_ns;

		for (int d = 0; d < VECTOR_DIM; d++) {
			out_vectors[d + output_count * VECTOR_DIM] = (double)slot->values[d];
		}
		output_count++;

		if (output_count >= max_events) {
			break;
		}
	}
	return output_count;
}

int julia_shm_read_adjacency(int max_nodes, double *out_matrix) {
	if (g_cytoplasm == NULL || out_matrix == NULL || max_nodes <= 0) {
		return 0;
	}

	int n = max_nodes;

	if (n > (int)GRAPH_MAX_NODES) {
		n = (int)GRAPH_MAX_NODES;
	}
	
	for (int j = 0; j < n; j++) {
		for (int i = 0; i < n; i++) {
			out_matrix[i + j * max_nodes] = (double)g_cytoplasm->adjacency_matrix.weights[i][j];
		}
	}

	uint32_t active = g_cytoplasm->header.active_node_count;

	if (active > (uint32_t)n) {
		active = (uint32_t)n;
	}

	return (int)active;
}

void julia_shm_write_sindy_model(const double *c0, const double *c1, const double *c2, const double *c3, const double *diffusion, double residual, double relative_residual, uint32_t active_term_mask, uint64_t fit_timestamp_ns) {
	if (g_cytoplasm == NULL || c0 == NULL || c1 == NULL || c2 == NULL || c3 == NULL || diffusion == NULL ) {
		return;
	}

	__atomic_add_fetch(&g_cytoplasm->sindy_extended.model_generation, 1, __ATOMIC_ACQ_REL);

	for (int d = 0; d < VECTOR_DIM; d++) {
		g_cytoplasm->coefficients.c1_diag[d] = c1[d];
		g_cytoplasm->coefficients.c2_diag[d] = c2[d];	
		g_cytoplasm->coefficients.diffusion_tensor[d] = diffusion[d];	
		g_cytoplasm->sindy_extended.c0_diag[d] = c0[d];		
		g_cytoplasm->sindy_extended.c3_diag[d] = c3[d];
	}

	g_cytoplasm->coefficients.residual_error = residual;
	g_cytoplasm->coefficients.fit_timestamp_ns = fit_timestamp_ns;
	g_cytoplasm->sindy_extended.relative_residual = relative_residual;
	g_cytoplasm->sindy_extended.fit_timestamp_ns = fit_timestamp_ns;
	g_cytoplasm->sindy_extended.schema_version = 1;
	g_cytoplasm->sindy_extended.active_term_mask = active_term_mask;

	__atomic_thread_fence(__ATOMIC_RELEASE);
	__atomic_add_fetch(&g_cytoplasm->sindy_extended.model_generation, 1, __ATOMIC_RELEASE);
}


