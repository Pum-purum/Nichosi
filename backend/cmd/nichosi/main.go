package main

import (
	"context"
	"crypto/subtle"
	"database/sql"
	"encoding/json"
	"errors"
	"fmt"
	"io/fs"
	"log/slog"
	"net"
	"net/http"
	"os"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/go-sql-driver/mysql"
)

type profile struct {
	Connection
	pool *sql.DB
}

type app struct {
	mu          sync.RWMutex
	connections []*profile
	token       string
	static      http.Handler
}

func main() {
	addr := env("NICHOSI_ADDR", "127.0.0.1:8080")
	token := os.Getenv("NICHOSI_ADMIN_TOKEN")
	if !isLoopback(addr) && len(token) < 24 {
		slog.Error("NICHOSI_ADMIN_TOKEN with at least 24 characters is required for non-loopback binding")
		os.Exit(1)
	}

	static, err := fs.Sub(webFiles, "static")
	if err != nil {
		slog.Error("frontend files unavailable", "error", err)
		os.Exit(1)
	}
	application := &app{token: token, static: http.FileServer(http.FS(static))}
	mux := http.NewServeMux()
	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.Handle("GET /api/connections", application.authorize(http.HandlerFunc(application.listConnections)))
	mux.Handle("POST /api/connections", application.authorize(http.HandlerFunc(application.createConnection)))
	mux.Handle("/", application.static)

	server := &http.Server{Addr: addr, Handler: mux, ReadHeaderTimeout: 5 * time.Second}
	slog.Info("Nichosi listening", "address", addr)
	if err := server.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		slog.Error("server stopped", "error", err)
		os.Exit(1)
	}
}

func (a *app) authorize(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if a.token != "" {
			provided := strings.TrimPrefix(r.Header.Get("Authorization"), "Bearer ")
			if subtle.ConstantTimeCompare([]byte(provided), []byte(a.token)) != 1 {
				writeError(w, http.StatusUnauthorized, "unauthorized", "Admin token is required")
				return
			}
		}
		next.ServeHTTP(w, r)
	})
}

func (a *app) listConnections(w http.ResponseWriter, _ *http.Request) {
	a.mu.RLock()
	defer a.mu.RUnlock()
	result := make([]Connection, 0, len(a.connections))
	for _, item := range a.connections {
		result = append(result, item.Connection)
	}
	writeJSON(w, http.StatusOK, result)
}

func (a *app) createConnection(w http.ResponseWriter, r *http.Request) {
	r.Body = http.MaxBytesReader(w, r.Body, 1<<20)
	var input ConnectionInput
	if err := json.NewDecoder(r.Body).Decode(&input); err != nil {
		writeError(w, http.StatusBadRequest, "invalid_request", "Invalid connection details")
		return
	}
	if input.Driver != ConnectionInputDriver("mysql") || input.Host == "" || input.Port < 1 || input.Port > 65535 || input.User == "" || input.Password == nil || *input.Password == "" || input.Database == "" {
		writeError(w, http.StatusBadRequest, "invalid_connection", "Provide valid MySQL connection details")
		return
	}
	cfg := mysql.NewConfig()
	cfg.User, cfg.Passwd = input.User, *input.Password
	cfg.Net, cfg.Addr, cfg.DBName = "tcp", net.JoinHostPort(input.Host, strconv.Itoa(input.Port)), input.Database
	cfg.Timeout, cfg.ReadTimeout, cfg.WriteTimeout = 5*time.Second, 5*time.Second, 5*time.Second
	cfg.ParseTime = true
	pool, err := sql.Open("mysql", cfg.FormatDSN())
	if err != nil {
		writeError(w, http.StatusBadRequest, "connection_failed", "Could not configure the database connection")
		return
	}
	pool.SetMaxOpenConns(5)
	pool.SetMaxIdleConns(2)
	ctx, cancel := context.WithTimeout(r.Context(), 8*time.Second)
	defer cancel()
	if err := pool.PingContext(ctx); err != nil {
		pool.Close()
		writeError(w, http.StatusBadGateway, "connection_failed", "Could not connect. Check the host, port, database and credentials.")
		return
	}
	var size int64
	if err := pool.QueryRowContext(ctx, "SELECT COALESCE(SUM(data_length + index_length), 0) FROM information_schema.tables WHERE table_schema = ?", input.Database).Scan(&size); err != nil {
		pool.Close()
		writeError(w, http.StatusBadGateway, "metadata_failed", "Connected, but could not read database metadata")
		return
	}
	now := time.Now().UTC()
	name := strings.TrimSpace(input.Name)
	if name == "" {
		name = input.Database
	}
	environment := input.Environment
	if environment != Environment("stage") && environment != Environment("prod") {
		environment = Environment("dev")
	}
	item := &profile{Connection: Connection{Id: fmt.Sprintf("conn-%d", now.UnixNano()), Name: name, Driver: ConnectionDriver("mysql"), Host: input.Host, Port: input.Port, User: input.User, Database: input.Database, Environment: environment, ReadOnly: environment == Environment("prod"), DatabaseSizeBytes: &size, LastConnectedAt: &now}, pool: pool}
	a.mu.Lock()
	a.connections = append(a.connections, item)
	a.mu.Unlock()
	writeJSON(w, http.StatusCreated, item)
}

func writeJSON(w http.ResponseWriter, status int, value any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(value)
}
func writeError(w http.ResponseWriter, status int, code, message string) {
	writeJSON(w, status, Error{Code: code, Message: message})
}
func env(key, fallback string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return fallback
}
func isLoopback(addr string) bool {
	host, _, err := net.SplitHostPort(addr)
	return err == nil && (host == "localhost" || net.ParseIP(host) != nil && net.ParseIP(host).IsLoopback())
}
