package main

/*
#cgo CPPFLAGS: -I${SRCDIR}/../../include
#include "cytoplasm_v4.h"

CytoplasmV4* cytoplasm_v4_attach(int *shmid_out);
int cytoplasm_v4_detach(CytoplasmV4 *cytoplasm);
void cytoplasm_v4_write_particle(CytoplasmV4 *cytoplasm, uint64_t write_idx, uint32_t slot_id, uint32_t role, double score, double ricci, uint64_t now_ns);
*/
import "C"

import (
	"fmt"
	"sync"
	"sync/atomic"
	"time"
	"unsafe"
)

type SharedMemoryWriter struct {
	shmPtr    *C.CytoplasmV4
	shmID     C.int
	nodeMap   map[string]int
	nodeCount int
	mu        sync.Mutex
}

func NewSharedMemoryWriter() (*SharedMemoryWriter, error) {
	var shmID C.int
	ptr := C.cytoplasm_v4_attach(&shmID)
	if ptr == nil {
		return nil, fmt.Errorf("failed to attach to Cytoplasm IV 512MB shared memory")
	}

	return &SharedMemoryWriter{
		shmPtr:  ptr,
		shmID:   shmID,
		nodeMap: make(map[string]int),
	}, nil
}

func (w *SharedMemoryWriter) getOrAssignNodeIndex(did string) int {
	w.mu.Lock()
	defer w.mu.Unlock()

	if idx, exists := w.nodeMap[did]; exists {
		return idx
	}

	if w.nodeCount < C.GRAPH_MAX_NODES {
		idx := w.nodeCount
		w.nodeMap[did] = idx
		w.nodeCount++
		atomic.StoreUint32((*uint32)(unsafe.Pointer(&w.shmPtr.header.active_node_count)), uint32(w.nodeCount))
		return idx
	}

	hash := 0
	for _, ch := range did {
		hash = (hash*31 + int(ch)) % C.GRAPH_MAX_NODES
	}
	return hash
}

func (w *SharedMemoryWriter) WritePost(uri, authorDID, text string, vector [128]float32, targetDID string) uint64 {
	nowNs := uint64(time.Now().UnixNano())

	// 1. Atomic Index Increment
	writeIdx := atomic.AddUint64((*uint64)(unsafe.Pointer(&w.shmPtr.header.write_index)), 1) - 1

	// 2. Vector Ring Buffer Write (~192MB Zone)
	vSlotIdx := writeIdx % C.VECTOR_RING_CAPACITY
	vSlot := &w.shmPtr.vectors[vSlotIdx]
	vSlot.slot_id = C.uint64_t(writeIdx)
	vSlot.timestamp_ns = C.uint64_t(nowNs)

	for i := 0; i < C.VECTOR_DIM; i++ {
		vSlot.values[i] = C.float(vector[i])
	}

	// 3. Text LRU Buffer Write (~320MB Zone)
	tSlotIdx := writeIdx % C.TEXT_LRU_CAPACITY
	tSlot := &w.shmPtr.text_lru[tSlotIdx]
	tSlot.slot_id = C.uint64_t(writeIdx)
	tSlot.timestamp_ns = C.uint64_t(nowNs)

	copyCString(unsafe.Pointer(&tSlot.uri[0]), uri, C.TEXT_URI_MAX_LEN)
	copyCString(unsafe.Pointer(&tSlot.author_did[0]), authorDID, C.TEXT_AUTHOR_MAX_LEN)
	copyCString(unsafe.Pointer(&tSlot.text[0]), text, C.TEXT_BODY_MAX_LEN)

	// 4. Graph Adjacency Matrix Update
	if targetDID != "" {
		srcIdx := w.getOrAssignNodeIndex(authorDID)
		dstIdx := w.getOrAssignNodeIndex(targetDID)

		weightPtr := &w.shmPtr.adjacency_matrix.weights[srcIdx][dstIdx]
		currentWeight := float32(*weightPtr)
		newWeight := currentWeight*0.95 + 1.0
		if newWeight > 10.0 {
			newWeight = 10.0
		}
		*weightPtr = C.float(newWeight)
	}

	// 5. Particle Output Area Update (C 言語ヘルパー関数経由で安全に書き込み)
	var role uint32
	if targetDID != "" {
		role = C.ROLE_VORTICITY_CENTER
	} else if len(text) > 120 {
		role = C.ROLE_BOUNDARY_BREAKER
	} else {
		role = C.ROLE_SINGULARITY_CATALYST
	}

	score := 0.75 + float64(writeIdx%25)/100.0
	ricci := -0.10 - float64(writeIdx%40)/100.0

	C.cytoplasm_v4_write_particle(
		w.shmPtr,
		C.uint64_t(writeIdx),
		C.uint32_t(tSlotIdx),
		C.uint32_t(role),
		C.double(score),
		C.double(ricci),
		C.uint64_t(nowNs),
	)

	atomic.StoreUint64((*uint64)(unsafe.Pointer(&w.shmPtr.header.last_updated_epoch_ns)), nowNs)

	return writeIdx
}

func copyCString(dst unsafe.Pointer, src string, maxLen int) {
	bytes := []byte(src)
	if len(bytes) >= maxLen {
		bytes = bytes[:maxLen-1]
	}
	dstBuf := (*[1 << 30]byte)(dst)[:maxLen:maxLen]
	copy(dstBuf, bytes)
	dstBuf[len(bytes)] = 0
}

func (w *SharedMemoryWriter) Close() {
	if w.shmPtr != nil {
		C.cytoplasm_v4_detach(w.shmPtr)
	}
}
