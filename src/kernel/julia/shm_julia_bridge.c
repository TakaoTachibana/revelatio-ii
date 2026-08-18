#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <stddef.h>
#include "cytoplasm_v4.h"

static CytoplasmV4 *g_cytoplasm = NULL;

int julia_shm_attach(void) {
	int shmid = shmget((key_t)CYTOPLASM_V4_IPC_KEY,sizeof(CytoplasmV4), 0666);
	if (shmid < 0) {
		return -1;
	}

	void *shm_ptr = shmat(shmid, NULL, 0);
	if (shm_ptr == (void *)-1) {
		return -2;
	}

	printf("[DEBUG SHM] mean_ricci offset: %zu | re_lambda offset: %zu\n",
			offsetof(HeaderSection, mean_ricci_curvature),
			offsetof(HeaderSection, re_lambda_max));

	g_cytoplasm = (CytoplasmV4 *)shm_ptr;
	return 0;
}

void julia_shm_read_header_raw(void *out_hdr) {
	if (g_cytoplasm == NULL || out_hdr == NULL) {
		return;
	}
	memcpy(out_hdr, &(g_cytoplasm->header), sizeof(HeaderSection));
}

int julia_shm_read_timeseries(int time_steps, double *out_matrix) {
	if (g_cytoplasm == NULL) {
		return 0;
	}

	uint64_t w_idx = g_cytoplasm->header.write_index;
	int steps = (time_steps > (int)VECTOR_RING_CAPACITY) ? (int)VECTOR_RING_CAPACITY : time_steps;

	for (int t = 0; t < steps; t++) {
		uint64_t target_idx = (w_idx > (uint64_t)t) ? (w_idx - 1 - t) : 0;
		uint32_t slot = (uint32_t)(target_idx % VECTOR_RING_CAPACITY);

		for (int d = 0; d < VECTOR_DIM; d++) {
			out_matrix[d + t * VECTOR_DIM] = (double)g_cytoplasm->vectors[slot].values[d];
		}
	}
	return steps;
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
	g_cytoplasm->header.state_flags &= ~clear_mask;
}

void julia_shm_detach(void) {
	if (g_cytoplasm != NULL) {
		shmdt((void *)g_cytoplasm);
		g_cytoplasm = NULL;
	}
}



