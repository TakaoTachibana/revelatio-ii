/**
 * @file cytoplasm_v4.h
 * @brief REVELATIO II Cytoplasm IV Shared Memory Layout Specification
 * @details System V Shared Memory (Key: 0x41504550 / "APEP", Size: 512 MB)
 */

#ifndef CYTOPLASM_V4_H
#define CYTOPLASM_V4_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/*=== Constant Definition === */

#define CYTOPLASM_V4_IPC_KEY 0x41504550U /* "APEP" */
#define CYTOPLASM_V4_SHM_SIZE (512U * 1024U * 1024) /* 512 MB */

/* Feature Vector Configuration */
#define VECTOR_DIM 128
#define VECTOR_RING_CAPACITY 262144U /* ~192 MB Ring Buffer */

/* Graph Topology Configuration */
#define GRAPH_MAX_NODES 256U /* Max Active Graph Nodes */

/* Text LRU Buffer Configuration */
#define TEXT_LRU_CAPACITY 16384U /* ~320 MB LRU Buffer */
#define TEXT_URI_MAX_LEN 256
#define TEXT_AUTHOR_MAX_LEN 128
#define TEXT_BODY_MAX_LEN 2048

/* Particle Attribution Output Area */
#define MAX_TOP_TRIGGER_POSTS 64U

/* System State Flags */
#define STATE_FLAG_STABLE 0x00
#define STATE_FLAG_QUIET 0x01
#define STATE_FLAG_PERTURBED 0x02
#define STATE_FLAG_CRITICAL 0x04
#define STATE_FLAG_TDA_DISRUPTION 0x08

/* Structural Role Flags for Particles */
#define ROLE_SINGULARITY_CATALYST 0x01
#define ROLE_BOUNDARY_BREAKER 0x02
#define ROLE_VORTICITY_CENTER 0x04

#pragma pack(push, 1)

/*=== 1. Header Section (256 Bytes) ===*/

typedef struct {
	uint64_t magic_number; /* 0x4150455052455634ULL ("APEPREV4") */
	uint64_t write_index; /*Atomic global write counter */
	uint64_t read_index; /*Global read pointer */
	double re_lambda_max; /* Real part of max eigenvalue */
	double mean_ricci_curvature; /* Average Ricci Curvature R_ver */
	uint32_t state_flags; /* SYSTEM STATE FLAGS */
	uint32_t active_node_count; /* Active nodes in graph topology */
	uint64_t last_updated_epoch_ns; /* Timestamp (nanoseconds) */
	uint8_t reserved[200];
} HeaderSection;

/*=== 2. Tensor Coefficient Section (1,024 Bytes) ===*/

typedef struct {
	/* Vector SINDy PDE Non-linear Coefficients (C1, C2 matrices in flattened/diagonol form) */
	double c1_diag[VECTOR_DIM];
	double c2_diag[VECTOR_DIM];
	/* Anisotropic Diffusion Tensor D (Diagonal representation) */
	double diffusion_tensor[VECTOR_DIM];
	double residual_error;
	double tda_h1_persistence;
	double tda_h2_persistence;
	uint64_t fit_timestamp_ns;
	uint8_t reserved[160];
} TensorCoefficientSection;

/*=== 3. Particle Attribution Output Area (15,104 Bytes) ===*/

typedef struct {
	uint32_t slot_id;
	uint32_t structural_role; /* Role flags (CATALYST / BREAKER / VORTICITY) */
	double attribution_score; /* S_i Score */
	double local_ricci_curvature; /* R_i Curvature */
} TriggerParticle;

typedef struct {
	uint32_t trigger_count;
	TriggerParticle particle[MAX_TOP_TRIGGER_POSTS];
	uint64_t calculated_at_ns;
	uint8_t reserved[128];
} ParticleOutputArea;

/*=== 4. Adjacency Matrix Section (262,144 Bytes) ===*/

typedef struct {
	/* 256 x 256 Dense Weight Matrix for Interaction Topology (Replay/Quote/Mention) */
	float weights[GRAPH_MAX_NODES][GRAPH_MAX_NODES];
} AdjacencyMatrixSection;

/*=== 5. Feature Vector Slot Struct (768 Bytes per Slot) ===*/

typedef struct {
	uint64_t slot_id;
	uint64_t timestamp_ns;
	float values[VECTOR_DIM]; /* 128-dimentional projected feature vector */
	uint8_t reserved[240];
} VectorSlot;

/*=== 6. Text Metadata LRU Slot Struct (20,480 Bytes per Slot) ===*/

typedef struct {
	uint64_t slot_id;
	uint64_t timestamp_ns;
	char uri[TEXT_URI_MAX_LEN];
	char author_did[TEXT_AUTHOR_MAX_LEN];
	char text[TEXT_BODY_MAX_LEN];
	double spectral_score;
	double local_ricci_curvature;
	uint32_t structural_role;
	uint8_t reserved[18012];
} TextSlot;

/*=== 7. Cytoplasm IV Full Shared Memory Structure (512 MB) ===*/

typedef struct {
	HeaderSection header; /* 0x00000000 - 256 B */
	TensorCoefficientSection coefficients; /* 0x00000100 - 3,264 B */
	ParticleOutputArea particles_output; /* 0x00000DC0 - 1,676 B */
	uint8_t reserved_meta[11188]; /* 0x0000144C -> to padding 0x00004000 */
	
	AdjacencyMatrixSection adjacency_matrix; /* 0x00004000 - 262,144 B */

	VectorSlot vectors[VECTOR_RING_CAPACITY]; /* 192 MB */
	TextSlot text_lru[TEXT_LRU_CAPACITY]; /* 320 MB */
} CytoplasmV4;

#pragma pack(pop)

/*=== Memory Layout Alignment Assertions (Compile-time Verification) ===*/

#ifdef __cplusplus
	#ifndef _Static_assert
		#define _Static_assert static_assert
	#endif
#endif

_Static_assert(sizeof(HeaderSection) == 256, "HeaderSection must be exactly 256 bytes");
_Static_assert(sizeof(TensorCoefficientSection) == 3256 || sizeof(TensorCoefficientSection) == 3264, "TensorCoefficientSection layout check");
_Static_assert(offsetof(CytoplasmV4, adjacency_matrix) == 0x4000, "Adjacency matrix offset must be exactly 0x4000 (16KB)");
_Static_assert(sizeof(VectorSlot) == 768, "VectorSlot size must be exactly 768 bytes");
_Static_assert(sizeof(TextSlot) == 20480, "TextSlot size must be exactly 20,480 bytes");

#ifdef __cplusplus
}
#endif

#endif /* CYTOPLASM_V4_H */


