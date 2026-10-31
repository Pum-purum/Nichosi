package main

import (
	"net/http"
	"net/http/httptest"
	"testing"
)

func TestGetTableMetadataConnectionState(t *testing.T) {
	application := &app{connections: []*profile{{Connection: Connection{Id: "closed"}}}}
	for _, tc := range []struct {
		id     string
		status int
	}{{"missing", http.StatusNotFound}, {"closed", http.StatusConflict}} {
		t.Run(tc.id, func(t *testing.T) {
			request := httptest.NewRequest(http.MethodGet, "/api/connections/"+tc.id+"/tables/t/metadata", nil)
			request.SetPathValue("connId", tc.id)
			request.SetPathValue("table", "t")
			response := httptest.NewRecorder()
			application.getTableMetadata(response, request)
			if response.Code != tc.status {
				t.Fatalf("status=%d", response.Code)
			}
		})
	}
}
