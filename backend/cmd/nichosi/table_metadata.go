package main

import (
	"context"
	"errors"
	"net/http"
	"time"

	"github.com/Pum-purum/nichosi/internal/driver"
)

func (a *app) getTableMetadata(w http.ResponseWriter, r *http.Request) {
	item := a.connection(r.PathValue("connId"))
	if item == nil {
		writeError(w, http.StatusNotFound, "not_found", "Connection not found")
		return
	}
	item.mu.RLock()
	defer item.mu.RUnlock()
	if item.pool == nil {
		writeError(w, http.StatusConflict, "disconnected", "Connection is closed")
		return
	}
	ctx, cancel := context.WithTimeout(r.Context(), 10*time.Second)
	defer cancel()
	metadata, err := driver.MySQLTableMetadata(ctx, item.pool, item.Database, r.PathValue("table"))
	if errors.Is(err, driver.ErrTableNotFound) {
		writeError(w, http.StatusNotFound, "not_found", "Table not found")
		return
	}
	if err != nil {
		writeError(w, http.StatusBadGateway, "metadata_failed", "Could not read table metadata")
		return
	}
	writeJSON(w, http.StatusOK, TableMetadata{Name: metadata.Name, Details: metadata.Details, Columns: metadata.Columns, Indexes: metadata.Indexes, ForeignKeys: metadata.ForeignKeys, Triggers: metadata.Triggers, Definition: metadata.Definition, Warnings: metadata.Warnings})
}
