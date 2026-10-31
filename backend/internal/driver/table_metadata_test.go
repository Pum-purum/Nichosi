package driver

import (
	"context"
	"database/sql"
	sqldriver "database/sql/driver"
	"errors"
	"github.com/go-sql-driver/mysql"
	"io"
	"strings"
	"testing"
)

type metadataConnector struct {
	mode, query string
	queries     []string
}

func (c *metadataConnector) Connect(context.Context) (sqldriver.Conn, error) {
	return &metadataConn{c}, nil
}
func (*metadataConnector) Driver() sqldriver.Driver { return definitionDriver{} }

type metadataConn struct{ c *metadataConnector }

func (*metadataConn) Prepare(string) (sqldriver.Stmt, error) { return nil, errors.New("unsupported") }
func (*metadataConn) Close() error                           { return nil }
func (*metadataConn) Begin() (sqldriver.Tx, error)           { return nil, errors.New("unsupported") }
func (c *metadataConn) QueryContext(_ context.Context, query string, args []sqldriver.NamedValue) (sqldriver.Rows, error) {
	c.c.queries = append(c.c.queries, query)
	c.c.query = query
	if strings.Contains(query, "information_schema.tables") {
		return &definitionRows{columns: []string{"Engine"}, values: []sqldriver.Value{"InnoDB"}, read: c.c.mode == "missing"}, nil
	}
	if strings.Contains(query, "information_schema.statistics") {
		if c.c.mode == "denied" {
			return nil, &mysql.MySQLError{Number: 1142, Message: "secret error"}
		}
		if c.c.mode == "broken" {
			return nil, errors.New("connection lost")
		}
	}
	if strings.HasPrefix(query, "SHOW CREATE TABLE") {
		if c.c.mode == "credentials" {
			return &definitionRows{columns: []string{"Create Table"}, values: []sqldriver.Value{"CREATE TABLE t (id int) ENGINE=FEDERATED CONNECTION='mysql://user:secret@host/db/t'"}}, nil
		}
		if c.c.mode == "hidden" {
			return &definitionRows{columns: []string{"Create Table"}, values: []sqldriver.Value{nil}}, nil
		}
		return &definitionRows{columns: []string{"Table", "Create Table"}, values: []sqldriver.Value{"t", "CREATE TABLE t (id int PRIMARY KEY)"}}, nil
	}
	if c.c.mode == "truncate" && strings.Contains(query, "information_schema.columns") {
		return &manyMetadataRows{}, nil
	}
	return &definitionRows{read: true}, nil
}

type manyMetadataRows struct{ count int }

func (*manyMetadataRows) Columns() []string { return []string{"Name"} }
func (*manyMetadataRows) Close() error      { return nil }
func (r *manyMetadataRows) Next(dest []sqldriver.Value) error {
	if r.count == 1001 {
		return io.EOF
	}
	dest[0] = "column"
	r.count++
	return nil
}

func TestMySQLTableMetadata(t *testing.T) {
	for _, tc := range []struct {
		mode    string
		wantErr bool
	}{{"ok", false}, {"missing", true}, {"denied", false}, {"broken", true}, {"truncate", false}} {
		t.Run(tc.mode, func(t *testing.T) {
			connector := &metadataConnector{mode: tc.mode}
			db := sql.OpenDB(connector)
			defer db.Close()
			result, err := MySQLTableMetadata(context.Background(), db, "db`name", "t'`name")
			if (err != nil) != tc.wantErr {
				t.Fatalf("err=%v", err)
			}
			if tc.mode == "missing" && !errors.Is(err, ErrTableNotFound) {
				t.Fatalf("want missing, got %v", err)
			}
			if tc.wantErr {
				return
			}
			if !strings.HasSuffix(connector.query, "`db``name`.`t'``name`") {
				t.Fatalf("unsafe definition query: %s", connector.query)
			}
			if result.Definition == "" || result.Details["Engine"] != "InnoDB" {
				t.Fatalf("missing metadata: %+v", result)
			}
			if tc.mode == "denied" && !strings.Contains(strings.Join(result.Warnings, " "), "Indexes metadata is unavailable") {
				t.Fatal(result.Warnings)
			}
			if tc.mode == "truncate" && (len(result.Columns) != 1000 || !strings.Contains(strings.Join(result.Warnings, " "), "limited to 1000")) {
				t.Fatalf("bad truncation: %d %v", len(result.Columns), result.Warnings)
			}
			for _, query := range connector.queries {
				if strings.Contains(query, "information_schema.") && (!strings.Contains(query, "LIMIT ") || strings.Contains(query, "t'`name")) {
					t.Fatalf("unbounded or interpolated query: %s", query)
				}
			}
		})
	}
}

func TestMetadataPermissionError(t *testing.T) {
	for _, tc := range []struct {
		err  error
		want bool
	}{{&mysql.MySQLError{Number: 1142}, true}, {&mysql.MySQLError{Number: 1044}, true}, {&mysql.MySQLError{Number: 2006}, false}, {context.DeadlineExceeded, false}} {
		if got := metadataPermissionError(tc.err); got != tc.want {
			t.Fatalf("%v: %v", tc.err, got)
		}
	}
}

func TestConnectionOptionDetection(t *testing.T) {
	for _, tc := range []struct {
		definition string
		want       bool
	}{
		{"CREATE TABLE t (id int)", false},
		{"CREATE TABLE t (id int) ENGINE=FEDERATED CONNECTION='mysql://user:password@host/db/t'", true},
		{"connection = 'server/table'", true},
	} {
		if got := connectionOption.MatchString(tc.definition); got != tc.want {
			t.Fatalf("connection option detection = %v", got)
		}
	}
}

func TestTableMetadataUnavailableDefinition(t *testing.T) {
	for _, mode := range []string{"credentials", "hidden"} {
		t.Run(mode, func(t *testing.T) {
			db := sql.OpenDB(&metadataConnector{mode: mode})
			defer db.Close()
			result, err := MySQLTableMetadata(context.Background(), db, "demo", "t")
			if err != nil {
				t.Fatal(err)
			}
			if result.Definition != "" || len(result.Warnings) < 2 {
				t.Fatalf("definition should be unavailable: %+v", result)
			}
			for _, warning := range result.Warnings {
				if strings.Contains(warning, "secret") {
					t.Fatal("credential leaked in warning")
				}
			}
		})
	}
}
