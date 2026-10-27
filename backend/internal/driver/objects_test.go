package driver

import (
	"context"
	"database/sql"
	_ "github.com/go-sql-driver/mysql"
	"os"
	"strings"
	"testing"
	"time"
)

func TestQuoteIdent(t *testing.T) {
	for _, tc := range []struct{ in, want string }{{"lab", "`lab`"}, {"a`b", "`a``b`"}} {
		if got := QuoteIdent(tc.in); got != tc.want {
			t.Errorf("QuoteIdent(%q) = %q", tc.in, got)
		}
	}
}

func TestMySQLDemoObjects(t *testing.T) {
	dsn := os.Getenv("NICHOSI_TEST_DSN")
	if dsn == "" {
		t.Skip("local MySQL DSN is not configured")
	}
	db, err := sql.Open("mysql", dsn)
	if err != nil {
		t.Fatal("open test database")
	}
	defer db.Close()
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err = db.PingContext(ctx); err != nil {
		t.Skip("local MySQL unavailable")
	}
	objects, warnings, err := MySQLObjects(ctx, db, "nichosi_lab")
	if err != nil {
		t.Fatal(err)
	}
	if len(warnings) > 0 {
		t.Fatalf("unexpected metadata warnings: %v", warnings)
	}
	_, missingWarnings, err := MySQLObjects(ctx, db, "nichosi_missing_metadata_schema")
	if err != nil || len(missingWarnings) != 1 {
		t.Fatalf("missing account view must produce a warning without failing schema discovery")
	}
	found := map[string]bool{}
	for _, object := range objects {
		if strings.HasPrefix(object.Name, "nichosi_demo_") || strings.Contains(object.Name, "'nichosi_demo_") {
			found[object.Type] = true
		}
		if object.Type != "user" && object.Type != "role" && object.Definition == "" {
			t.Errorf("missing definition for %s", object.Name)
		}
	}
	for _, kind := range []string{"view", "trigger", "procedure", "function", "event", "user", "role"} {
		if !found[kind] {
			t.Errorf("missing demo %s", kind)
		}
	}
}
