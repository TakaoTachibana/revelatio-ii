package main

import (
	"crypto/md5"
	"encoding/binary"
	"encoding/json"
	"fmt"
	"log"
	"math"
	"os"
	"os/signal"
	"strings"
	"syscall"
	"time"
	"unicode/utf8"

	"github.com/gorilla/websocket"
)

const JetstreamEndpoint = "wss://jetstream2.us-east.bsky.network/subscribe?wantedCollections=app.bsky.feed.post"

type JetstreamEvent struct {
	Did string `json:"did"`
	Kind string `json:"kind"`
	Commit *struct {
		Action string `json:"action"`
		Collection string `json:"collection"`
		RKey string `json:"rkey"`
		Record struct {
			Type string `json:"$type"`
			Text string `json:"text"`
			CreatedAt string `json:"createdAt"`
			Reply *struct {
				Parent struct {
					Uri string `json:"uri"`
				} `json:"parent"`
				Root struct {
					Uri string `json:"uri"`
				} `json:"root"`
			} `json:"reply"`
		} `json:"record"`
	} `json:"commit"`
}

func ExtractFeatureVector128(text string) [128]float32 {
	var vec [128]float32
	if len(text) == 0 {
		return vec
	}

	runes := []rune(strings.ToLower(text))
	n := len(runes)

	for i := 0; i < n; i++ {
		var ngram string
		if i + 3 <= n {
			ngram = string(runes[i : i + 3])
		} else {
			ngram = string(runes[i:])
		}

		hash := md5.Sum([]byte(ngram))
		idx1 := binary.BigEndian.Uint32(hash[0:4]) % 128
		idx2 := binary.BigEndian.Uint32(hash[4:8]) % 128
		val := float32((int(hash[8]) % 2) + 2 - 1)

		vec[idx1] += val
		vec[idx2] += val * 0.5
	}

	var normSq float32
	for i := 0; i < 128; i++ {
		normSq += vec[i] * vec[i]
	}
	if normSq > 0 {
		norm := float32(math.Sqrt(float64(normSq)))
		for i := 0; i < 128; i++ {
			vec[i] /= norm
		}
	}

	return vec
}

func ExtractDIDFromURI(uri string) string {
	if strings.HasPrefix(uri, "at://") {
		parts := strings.Split(uri[5:], "/")
		if len(parts) > 0 {
			return parts[0]
		}
	}
	return ""
}

func safeTruncateUTF8(s string, maxBytes int) string {
	if len(s) <= maxBytes {
		return s
	}
	for maxBytes > 0 && !utf8.RuneStart(s[maxBytes]) {
		maxBytes--
	}
	return s[:maxBytes]
}

func main() {
	log.Println("[REVELATIO II Ingester] Initializing Cytoplasm IV (512MB) Shared Memory Writer...")

	shmWriter, err := NewSharedMemoryWriter()
	if err != nil {
		log.Fatalf("[FATAL] Shared memory attach error: %v", err)
	}
	defer shmWriter.Close()

	log.Printf("[REVELATIO II Ingester] Dialing Bluesky Jetstream API: %s", JetstreamEndpoint)
	
	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt, syscall.SIGTERM)

	conn, _, err := websocket.DefaultDialer.Dial(JetstreamEndpoint, nil)
	if err != nil {
		log.Fatalf("[FATAL] WebSoket connection error: %v", err)
	}
	defer conn.Close()

	log.Println("[REVELATIO II Ingester] Stream Connected! Ingestint 128D Vector & Topology into Cytoplasm IV...")

	done := make(chan struct{})

	go func() {
		defer close(done)
		var processedCount uint64

		for {
			_, message, err := conn.ReadMessage()
			if err != nil {
				log.Printf("[ERROR] WebSocket read error: %v", err)
				return
			}

			var event JetstreamEvent
			if err := json.Unmarshal(message, &event); err != nil || event.Kind != "commit" || event.Commit == nil {
				continue
			}

			if event.Commit.Collection == "app.bsky.feed.post" && (event.Commit.Action == "create" || event.Commit.Action == "") {
				text := event.Commit.Record.Text
				if len(text) == 0 {
					continue
				}

				safeText := safeTruncateUTF8(text, 2048)
				uri := fmt.Sprintf("at://%s/%s/%s", event.Did, event.Commit.Collection, event.Commit.RKey)
				authorDID := event.Did
				vector128 := ExtractFeatureVector128(safeText)

				var targetDID string
				if event.Commit.Record.Reply != nil {
					targetDID = ExtractDIDFromURI(event.Commit.Record.Reply.Parent.Uri)
				}

				slotIdx := shmWriter.WritePost(uri, authorDID, safeText, vector128, targetDID)
				processedCount++

				if processedCount == 1 || processedCount % 500 == 0 {
					log.Printf("[REVELATIO II Ingester] Streamed %d posts | Latest Slot: %d | Author: %s",
					processedCount, slotIdx, authorDID[:18]+"...")
				}
			}
		}
	}()

	select {
	case <-interrupt:
		log.Println("[REVELATIO II Ingester] Shutting down stream consumer...")
		conn.WriteMessage(websocket.CloseMessage, websocket.FormatCloseMessage(websocket.CloseNormalClosure, ""))
		select {
		case <-done:
		case <-time.After(time.Second):
		}
	case <-done:
	}

	log.Println("[REVELATIO II Ingester] Shutdonw complete.")
}



