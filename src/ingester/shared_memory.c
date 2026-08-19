#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include "cytoplasm_v4.h"

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
		cytoplasm->header.magic_number = 0x4150455052455634ULL;
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

/* C 言語側で #pragma pack(1) 構造体へ安全に直接書き込む関数 */
void cytoplasm_v4_write_particle(CytoplasmV4 *cytoplasm, uint64_t write_idx, uint32_t slot_id, uint32_t role, double score, double ricci, uint64_t now_ns) {
	if (cytoplasm == NULL) return;

	ParticleOutputArea *pOut = &(cytoplasm->particles_output);
	uint32_t pIdx = (uint32_t)(write_idx % MAX_TOP_TRIGGER_POSTS);

	/* cytoplasm_v4.h 内の配列フィールド（particle）へ直接代入 */
	pOut->particle[pIdx].slot_id = slot_id;
	pOut->particle[pIdx].structural_role = role;
	pOut->particle[pIdx].attribution_score = score;
	pOut->particle[pIdx].local_ricci_curvature = ricci;

	if (pOut->trigger_count < MAX_TOP_TRIGGER_POSTS) {
		pOut->trigger_count++;
	}
	pOut->calculated_at_ns = now_ns;
}
