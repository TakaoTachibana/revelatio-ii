#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include "cytoplasm_v4.h"

static CytoplasmV4 *g_cytoplasm = NULL;

void r_shm_attach(int *status) {
	int shmid = shmget((key_t)CYTOPLASM_V4_IPC_KEY, sizeof(CytoplasmV4), 0666);
	if (shmid < 0) {
		*status = -1;
		return;
	}

	void *shm_ptr = shmat(shmid, NULL, 0);
	if (shm_ptr == (void *)-1) {
		*status = -2;
		return;
	}

	g_cytoplasm = (CytoplasmV4 *)shm_ptr;
	*status = 0;
}

void r_shm_read_recent_vectors(int *smaple_count, double *out_matrix, double *out_timestamps) {
	if (g_cytoplasm == NULL) {
		return;
	}

	uint64_t w_idx = g_cytoplasm->header.write_index;
	int count = *smaple_count;
	if (count > (int)VECTOR_RING_CAPACITY) {
		count = (int)VECTOR_RING_CAPACITY;
	}

	for (int i = 0; i < count; i++) {
		uint64_t target_idx = (w_idx > (uint64_t)i) ? (w_idx - 1 - i) : 0;
		uint32_t slot = (uint32_t)(target_idx % VECTOR_RING_CAPACITY);

		out_timestamps[i] = (double)g_cytoplasm->vectors[slot].timestamp_ns;
		for (int d = 0; d < VECTOR_DIM; d++) {
			out_matrix[i * VECTOR_DIM + d] = (double)g_cytoplasm->vectors[slot].values[d];
		}
	}
}

void r_shm_read_adjacency_matrix(double *out_adj_256x256, int *active_nodes) {
	if (g_cytoplasm == NULL) {
		return;
	}

	*active_nodes = (int)g_cytoplasm->header.active_node_count;
	for (int i = 0; i < (int)GRAPH_MAX_NODES; i++) {
		for (int j = 0; j < (int)GRAPH_MAX_NODES; j++) {
			out_adj_256x256[i * GRAPH_MAX_NODES + j] = (double)g_cytoplasm->adjacency_matrix.weights[i][j];
		}
	}
}

void r_shm_update_metrics(double *mean_ricci, double *h1_persistence, double *h2_persistence, int *state_flags) {
	if (g_cytoplasm == NULL) {
		return;
	}

	g_cytoplasm->header.mean_ricci_curvature = *mean_ricci;
	g_cytoplasm->coefficients.tda_h1_persistence = *h1_persistence;
	g_cytoplasm->coefficients.tda_h2_persistence = *h2_persistence;
	g_cytoplasm->header.state_flags = (uint32_t)(*state_flags);
}

void r_shm_detach(void) {
	if (g_cytoplasm != NULL) {
		shmdt((void *)g_cytoplasm);
		g_cytoplasm = NULL;
	}
}


