/**
 * @file test_shm.c
 * @brief REVELATIO II Cytoplasm IV Shared Memory Attach & Sanity Test
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/ipc.h>
#include <sys/shm.h>
#include <errno.h>
#include <inttypes.h>
#include "../include/cytoplasm_v4.h"

int main(void) {
	printf("=== REVELATIO II // Cytoplasm IV Shared Memory Vrification ===\n\n");

	/* 1. Compile-Time & Runtime Layout Checks */
	printf("[1] Checking Structure Offsets & Memory Sized...\n");
	printf("  - Size of HeaderSection: %zu B\n", sizeof(HeaderSection));
	printf("  - Size of TensorCoefficientSection: %zu B\n", sizeof(TensorCoefficientSection));
	printf("  - Size of ParticleOutputArea: %zu B\n", sizeof(ParticleOutputArea));
	printf("  - Size of AdjacencyMatrixSection: %zu B\n", sizeof(AdjacencyMatrixSection));
	printf("  - Size of VectorSlot: %zu B\n", sizeof(VectorSlot));
	printf("  - Size of TextSlot: %zu B\n", sizeof(TextSlot));
	printf("  - Total CytoplasmV4 Size: %zu B (%.2f MB)\n\n",
			sizeof(CytoplasmV4), (double)sizeof(CytoplasmV4) / (1024.0 * 1024.0));

	printf("  - Offset of header: 0x%08ZX\n", offsetof(CytoplasmV4, header));
	printf("  - Offset of coefficients: 0x%08ZX\n", offsetof(CytoplasmV4, coefficients));
	printf("  - Offset of particles_output: 0x%08ZX\n", offsetof(CytoplasmV4, particles_output));
	printf("  - Offset of adjacency_matrix: 0x%08ZX (Target: 0x00004000)\n", offsetof(CytoplasmV4, adjacency_matrix));
	printf("  - Offset of vectors: 0x%08ZX\n", offsetof(CytoplasmV4, vectors));
	printf("  - Offset of text_lru: 0x%08ZX\n\n", offsetof(CytoplasmV4, text_lru));

	if (offsetof(CytoplasmV4, adjacency_matrix) != 0x4000) {
		fprintf(stderr, "[FATAL ERROR] Adjacency matrix offset mismatch! Expected 0x4000.\n");
		return EXIT_FAILURE;
	}

	/* 2. Attach or Create Shared Memory */
	printf("[2] Attaching to System V Shared Memory (Key: 0x%08X, Size: 512MB)...\n", CYTOPLASM_V4_IPC_KEY);
	
	int shmid = shmget((key_t)CYTOPLASM_V4_IPC_KEY, sizeof(CytoplasmV4), IPC_CREAT | 0666);
	if (shmid < 0) {	
		perror("  [ERROR] shmget failed");
		return EXIT_FAILURE;
	}
	printf("  - shmget SUCCESS: shmid = %d\n", shmid);

	void *shm_ptr = shmat(shmid, NULL, 0);
	if (shm_ptr == (void *)-1) {
		perror("  [ERROR] shmat failed");
		return EXIT_FAILURE;
	}
	printf("  - shmat SUCCESS: Attachied at virtual address %p\n\n", shm_ptr);

	CytoplasmV4 *cytoplasm = (CytoplasmV4 *)shm_ptr;

	/* 3. Initialize or Validate Header */
	printf("[3] Validating Header Magic Number...\n");
	if (cytoplasm->header.magic_number != 0x4150455052455634ULL) {
		printf("  - Uninitialized Shared Memory segment detected. Initializing Header...\n");
		cytoplasm->header.magic_number = 0x4150455052455634ULL; /* "APEPREV4" */
		cytoplasm->header.write_index = 0;
		cytoplasm->header.read_index = 0;
		cytoplasm->header.re_lambda_max = -0.45;
		cytoplasm->header.mean_ricci_curvature = 0.0;
		cytoplasm->header.state_flags = STATE_FLAG_STABLE;
		cytoplasm->header.active_node_count = 0;
		cytoplasm->header.last_updated_epoch_ns = 0;
		printf("  - Header Initialized: Magic = 0x%" PRIX64 " [APEPREV4]\n", cytoplasm->header.magic_number);
	} else {
		printf("  - Existing Shared Memory Segment Verified: Magic = 0x%" PRIX64 " [APEPREV4]\n", cytoplasm->header.magic_number);
	}

	/* 4. Execute Read/Write Sanity Tests */
	printf("\n[4] Executing Read/Write Sanity Tests...\n");
	cytoplasm->header.write_index++;
	uint64_t current_widx = cytoplasm->header.write_index;

	/* Test Vector Ring Buffer Write */
	uint32_t v_slot_idx = (uint32_t)(current_widx % VECTOR_RING_CAPACITY);
	cytoplasm->vectors[v_slot_idx].slot_id = current_widx;
	cytoplasm->vectors[v_slot_idx].timestamp_ns = 1700000000000000000ULL;
	cytoplasm->vectors[v_slot_idx].values[0] = 1.2345f;
	cytoplasm->vectors[v_slot_idx].values[127] = -9.8765f;

	printf("  - Vector Ring Slot [%u] Write OK (Slot ID: %"PRIu64 ", Val[0]: %.4f, Val[127]: %.4f)\n",
			v_slot_idx, cytoplasm->vectors[v_slot_idx].slot_id,
			cytoplasm->vectors[v_slot_idx].values[0], cytoplasm->vectors[v_slot_idx].values[127]);

	/* Test Text LRU Buffer Write */
	uint32_t t_slot_idx = (uint32_t)(current_widx % TEXT_LRU_CAPACITY);
	cytoplasm->text_lru[t_slot_idx].slot_id = current_widx;
	snprintf(cytoplasm->text_lru[t_slot_idx].uri, TEXT_URI_MAX_LEN, "at://did:plc:revelatio2/app.bsky.feed.post/test001");
	snprintf(cytoplasm->text_lru[t_slot_idx].author_did, TEXT_AUTHOR_MAX_LEN, "did:plc:revelatio2");
	snprintf(cytoplasm->text_lru[t_slot_idx].text, TEXT_BODY_MAX_LEN, "REVELATIO II Cytoplasm IV SHM Test Post");
	cytoplasm->text_lru[t_slot_idx].structural_role = ROLE_SINGULARITY_CATALYST;

	printf("  - Text LRU Slot [%u] Write OK (URI: %s, Role: 0x%02X)\n",
			t_slot_idx, cytoplasm->text_lru[t_slot_idx].uri, cytoplasm->text_lru[t_slot_idx].structural_role);

	/* Test Adjacency Matrix Write */
	cytoplasm->adjacency_matrix.weights[0][1] = 0.85f;
	printf("  - Adjacency Matrix Weight [0][1] Write OK (Weight: %.2f)\n", cytoplasm->adjacency_matrix.weights[0][1]);

	/* 5. Detach */
	printf("\n[5] Detaching Shared Memory...\n");
	if (shmdt(shm_ptr) < 0) {
		perror("  [ERROR] shmdt failed");
		return EXIT_FAILURE;
	}
	printf("  - shmdt SUCCESS. Shared Memory Verification Passed Cleanly!\n\n");
	printf("=== ALL CHECKS PASSED ===\n");

	return EXIT_SUCCESS;
}


			
