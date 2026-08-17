#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include "../../include/cytoplasm_v4.h"

CytoplasmV4* cytoplasm_v4_attach(int *shmid_out) {
	int shmid = shmget((key_t)CYTOPLASM_V4_IPC_KEY, sizeof(CytoplasmV4), IPC_CREAT | 0666);
	if (shmid < 0) {
		perror("[Cytoplasm IV C-Error] shmget failed");
		return NULL;
	}

	void *shm_ptr = shmat(shmid, NULL, 0);
	if (shm_ptr == (void *)-1) {
		perror("[Cytoplasm IV C-Error] shmat failed");
		return NULL;
	}

	if (shmid_out != NULL) {
		*shmid_out = shmid;
	}

	CytoplasmV4 *cytoplasm = (CytoplasmV4 *)shm_ptr;

	if (cytoplasm->header.magic_number != 0x4150455052455634ULL) {
		cytoplasm->header.magic_number = 0x4150455052455634ULL; /* "APERREV4" */
		cytoplasm->header.re_lambda_max = -0.45;
		cytoplasm->header.mean_ricci_curvature = 0.0;
		cytoplasm->header.state_flags = STATE_FLAG_STABLE;
		cytoplasm->header.write_index = 0;
		cytoplasm->header.read_index = 0;
		cytoplasm->header.active_node_count = 0;
	}

	return cytoplasm;
}

int cytoplasm_v4_detach(CytoplasmV4 *cytoplasm) {
	if (cytoplasm == NULL) {
		return -1;
	}

	return shmdt((void *)cytoplasm);
}



