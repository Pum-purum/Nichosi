package main

import (
	"encoding/json"
	"net/http/httptest"
	"os"
	"path/filepath"
	"strings"
	"testing"
)

func TestLoadConfiguredConnectionsReadonly(t *testing.T) {
	for _, tc := range []struct {
		name, setting string
		want          bool
		invalid       bool
	}{
		{name: "true", setting: `,"readonly":true`, want: true},
		{name: "false", setting: `,"readonly":false`, want: false},
		{name: "missing", want: true},
		{name: "null", setting: `,"readonly":null`, want: true},
		{name: "legacy production", setting: `,"environment":"prod"`, want: true},
		{name: "legacy development", setting: `,"environment":"dev"`, want: true},
		{name: "string is invalid", setting: `,"readonly":"false"`, invalid: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			file := filepath.Join(t.TempDir(), "connections.json")
			config := `{"connections":[{"name":"Local","driver":"mysql","host":"127.0.0.1","port":3306,"user":"tester","database":"lab","password":"test-password"` + tc.setting + `}]}`
			if err := os.WriteFile(file, []byte(config), 0600); err != nil {
				t.Fatal(err)
			}
			t.Setenv("NICHOSI_CONNECTIONS_FILE", file)
			application := &app{}
			application.loadConfiguredConnections()
			if tc.invalid {
				if len(application.connections) != 0 {
					t.Fatal("invalid boolean config must not load profiles")
				}
				return
			}
			if len(application.connections) != 1 {
				t.Fatalf("loaded %d profiles, want 1", len(application.connections))
			}
			item := application.connections[0]
			if item.Readonly != tc.want {
				t.Errorf("readonly=%v, want %v", item.Readonly, tc.want)
			}
			if item.input.Readonly == nil || *item.input.Readonly != tc.want {
				t.Error("reconnect input must preserve the normalized readonly setting")
			}
			if item.Connected || item.pool != nil {
				t.Error("configured profiles must start disconnected")
			}
			response := httptest.NewRecorder()
			application.listConnections(response, httptest.NewRequest("GET", "/api/connections", nil))
			body := response.Body.String()
			for _, forbidden := range []string{`"password"`, "test-password", `"environment"`, `"readOnly"`} {
				if strings.Contains(body, forbidden) {
					t.Error("connection response exposes a secret or obsolete property")
				}
			}
			var returned []Connection
			if err := json.Unmarshal(response.Body.Bytes(), &returned); err != nil {
				t.Fatal(err)
			}
			if len(returned) != 1 || returned[0].Readonly != tc.want {
				t.Fatal("connection response must include the configured readonly setting")
			}
		})
	}
}

func TestConnectionInputReadonlyDefault(t *testing.T) {
	for _, tc := range []struct {
		name, body string
		want       bool
		invalid    bool
	}{
		{name: "missing", body: `{}`, want: true},
		{name: "null", body: `{"readonly":null}`, want: true},
		{name: "true", body: `{"readonly":true}`, want: true},
		{name: "false", body: `{"readonly":false}`, want: false},
		{name: "invalid string", body: `{"readonly":"false"}`, invalid: true},
	} {
		t.Run(tc.name, func(t *testing.T) {
			var input ConnectionInput
			err := json.Unmarshal([]byte(tc.body), &input)
			if tc.invalid {
				if err == nil {
					t.Fatal("string readonly must be rejected")
				}
				return
			}
			if err != nil {
				t.Fatal(err)
			}
			if got := connectionReadonly(input.Readonly); got != tc.want {
				t.Errorf("readonly=%v, want %v", got, tc.want)
			}
		})
	}
}
