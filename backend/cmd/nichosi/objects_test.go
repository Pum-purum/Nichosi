package main

import (
	"net/http"
	"net/http/httptest"
	"net/url"
	"testing"
)

func TestGetObjectDefinitionValidation(t *testing.T) {
	application := &app{connections: []*profile{{Connection: Connection{Id: "closed"}}}}
	for _, tc := range []struct {
		name, kind, object, connection string
		status                         int
	}{
		{"account SQL forbidden", "user", "root", "closed", http.StatusBadRequest},
		{"role SQL forbidden", "role", "reader", "closed", http.StatusBadRequest},
		{"injected type", "EVENT; SHOW CREATE USER root", "event", "closed", http.StatusBadRequest},
		{"missing type", "", "event", "closed", http.StatusBadRequest},
		{"missing name", "event", "", "closed", http.StatusBadRequest},
		{"unknown connection", "event", "event", "unknown", http.StatusNotFound},
		{"disconnected", "event", "event", "closed", http.StatusConflict},
	} {
		t.Run(tc.name, func(t *testing.T) {
			query := url.Values{"type": {tc.kind}, "name": {tc.object}}
			request := httptest.NewRequest(http.MethodGet, "/api/connections/"+tc.connection+"/object-definition?"+query.Encode(), nil)
			request.SetPathValue("connId", tc.connection)
			response := httptest.NewRecorder()
			application.getObjectDefinition(response, request)
			if response.Code != tc.status {
				t.Fatalf("status=%d, want %d: %s", response.Code, tc.status, response.Body.String())
			}
		})
	}
}
