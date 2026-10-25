package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	addr := os.Getenv("NICHOSI_ADDR")
	if addr == "" {
		addr = "127.0.0.1:8080"
	}

	mux := http.NewServeMux()
	mux.HandleFunc("/api/health", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		_, _ = w.Write([]byte(`{"status":"ok"}`))
	})

	log.Printf("nichosi listening on %s", addr)
	log.Fatal(http.ListenAndServe(addr, mux))
}
