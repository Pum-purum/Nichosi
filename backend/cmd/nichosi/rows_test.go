package main

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"io"
	"net"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/go-sql-driver/mysql"
)

type tableCheckConnector struct{ err error }

func (c tableCheckConnector) Connect(context.Context) (driver.Conn, error) {
	return tableCheckConn{err: c.err}, nil
}
func (c tableCheckConnector) Driver() driver.Driver { return tableCheckDriver{} }

type tableCheckDriver struct{}

func (tableCheckDriver) Open(string) (driver.Conn, error) { return nil, errors.New("use connector") }

type tableCheckConn struct{ err error }

func (c tableCheckConn) Prepare(string) (driver.Stmt, error) { return nil, errors.New("not supported") }
func (c tableCheckConn) Close() error                        { return nil }
func (c tableCheckConn) Begin() (driver.Tx, error)           { return nil, errors.New("not supported") }
func (c tableCheckConn) QueryContext(context.Context, string, []driver.NamedValue) (driver.Rows, error) {
	if c.err != nil {
		return nil, c.err
	}
	return &tableCheckRows{}, nil
}

type tableCheckRows struct{ read bool }

func (*tableCheckRows) Columns() []string { return []string{"COUNT(*)"} }
func (*tableCheckRows) Close() error      { return nil }
func (r *tableCheckRows) Next(values []driver.Value) error {
	if r.read {
		return io.EOF
	}
	r.read = true
	values[0] = int64(0)
	return nil
}

func TestQueryRowsTableAvailability(t *testing.T) {
	for _, tc := range []struct {
		name   string
		err    error
		status int
		code   string
	}{
		{"missing table", nil, http.StatusNotFound, "table_not_found"},
		{"database stopped", &net.OpError{Op: "dial", Net: "tcp", Err: errors.New("private connection details")}, http.StatusBadGateway, "metadata_failed"},
		{"broken connection", driver.ErrBadConn, http.StatusBadGateway, "metadata_failed"},
		{"timeout", context.DeadlineExceeded, http.StatusBadGateway, "metadata_failed"},
		{"metadata permission denied", &mysql.MySQLError{Number: 1142, Message: "SELECT command denied to user 'viewer' for table 'tables'"}, http.StatusBadGateway, "metadata_failed"},
		{"multiline HTML text", errors.New("database error\n<script>alert('test')</script> & details"), http.StatusBadGateway, "metadata_failed"},
	} {
		t.Run(tc.name, func(t *testing.T) {
			pool := sql.OpenDB(tableCheckConnector{err: tc.err})
			defer pool.Close()
			application := &app{connections: []*profile{{Connection: Connection{Id: "test", Database: "demo"}, pool: pool}}}
			request := httptest.NewRequest(http.MethodPost, "/api/connections/test/tables/demo/rows", strings.NewReader("{}"))
			request.SetPathValue("connId", "test")
			request.SetPathValue("table", "demo")
			response := httptest.NewRecorder()
			application.queryRows(response, request)
			var body Error
			if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
				t.Fatal(err)
			}
			if response.Code != tc.status || body.Code != tc.code {
				t.Fatalf("status/code = %d/%s, want %d/%s", response.Code, body.Code, tc.status, tc.code)
			}
			if tc.err != nil && body.Message != tc.err.Error() {
				t.Fatalf("message = %q, want exact database error %q", body.Message, tc.err.Error())
			}
			if strings.Contains(response.Body.String(), "<script>") {
				t.Fatal("JSON response must escape HTML without altering the decoded message")
			}
		})
	}
}
