package main

import (
	"context"
	"database/sql"
	"database/sql/driver"
	"encoding/json"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

type errorStep struct {
	columns           []string
	values            [][]driver.Value
	queryErr, nextErr error
}
type errorConnector struct {
	steps []errorStep
	next  int
}

func (c *errorConnector) Connect(context.Context) (driver.Conn, error) { return &errorConn{c}, nil }
func (*errorConnector) Driver() driver.Driver                          { return tableCheckDriver{} }

type errorConn struct{ c *errorConnector }

func (*errorConn) Prepare(string) (driver.Stmt, error) { return nil, errors.New("not supported") }
func (*errorConn) Close() error                        { return nil }
func (*errorConn) Begin() (driver.Tx, error)           { return nil, errors.New("not supported") }
func (c *errorConn) QueryContext(context.Context, string, []driver.NamedValue) (driver.Rows, error) {
	if c.c.next >= len(c.c.steps) {
		return nil, errors.New("unexpected query")
	}
	step := c.c.steps[c.c.next]
	c.c.next++
	if step.queryErr != nil {
		return nil, step.queryErr
	}
	return &errorRows{step: step}, nil
}

type errorRows struct {
	step errorStep
	next int
}

func (r *errorRows) Columns() []string { return r.step.columns }
func (*errorRows) Close() error        { return nil }
func (r *errorRows) Next(values []driver.Value) error {
	if r.next >= len(r.step.values) {
		if r.step.nextErr != nil {
			return r.step.nextErr
		}
		return io.EOF
	}
	copy(values, r.step.values[r.next])
	r.next++
	return nil
}

func TestDatabaseReadErrorsArePreserved(t *testing.T) {
	source := errors.New("read failed\n<database> & driver details")
	count := errorStep{columns: []string{"COUNT(*)"}, values: [][]driver.Value{{int64(1)}}}
	columns := errorStep{columns: []string{"COLUMN_NAME", "COLUMN_TYPE", "IS_NULLABLE", "COLUMN_KEY"}, values: [][]driver.Value{{"id", "int", "NO", "PRI"}}}
	table := errorStep{columns: []string{"TABLE_NAME", "TABLE_ROWS", "DATA_LENGTH", "INDEX_LENGTH"}, values: [][]driver.Value{{"demo", int64(1), int64(0), int64(0)}}}
	for _, tc := range []struct {
		name   string
		schema bool
		steps  []errorStep
		want   string
		scan   bool
	}{
		{name: "schema query", schema: true, steps: []errorStep{{queryErr: source}}, want: source.Error()},
		{name: "schema iteration", schema: true, steps: []errorStep{{columns: table.columns, nextErr: source}}, want: source.Error()},
		{name: "schema scan", schema: true, steps: []errorStep{{columns: table.columns, values: [][]driver.Value{{"demo", "invalid integer", int64(0), int64(0)}}}}, scan: true},
		{name: "schema column query", schema: true, steps: []errorStep{table, {queryErr: source}}, want: source.Error()},
		{name: "schema column iteration", schema: true, steps: []errorStep{table, {columns: columns.columns, nextErr: source}}, want: source.Error()},
		{name: "schema column scan", schema: true, steps: []errorStep{table, {columns: []string{"missing"}, values: [][]driver.Value{{"id"}}}}, scan: true},
		{name: "row column query", steps: []errorStep{count, {queryErr: source}}, want: source.Error()},
		{name: "row count", steps: []errorStep{count, columns, {queryErr: source}}, want: source.Error()},
		{name: "row column iteration", steps: []errorStep{count, {columns: columns.columns, nextErr: source}, count}, want: source.Error()},
		{name: "row column scan", steps: []errorStep{count, {columns: []string{"missing"}, values: [][]driver.Value{{"id"}}}, count}, scan: true},
		{name: "row query", steps: []errorStep{count, columns, count, {queryErr: source}}, want: source.Error()},
		{name: "row iteration", steps: []errorStep{count, columns, count, {columns: []string{"id"}, nextErr: source}}, want: source.Error()},
	} {
		t.Run(tc.name, func(t *testing.T) {
			pool := sql.OpenDB(&errorConnector{steps: tc.steps})
			defer pool.Close()
			application := &app{connections: []*profile{{Connection: Connection{Id: "test", Database: "demo"}, pool: pool}}}
			request := httptest.NewRequest(http.MethodPost, "/", strings.NewReader("{}"))
			request.SetPathValue("connId", "test")
			request.SetPathValue("table", "demo")
			response := httptest.NewRecorder()
			if tc.schema {
				application.getSchema(response, request)
			} else {
				application.queryRows(response, request)
			}
			var body Error
			if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
				t.Fatal(err)
			}
			if response.Code != http.StatusBadGateway {
				t.Fatalf("status=%d, message=%q", response.Code, body.Message)
			}
			if tc.scan {
				if !strings.HasPrefix(body.Message, "sql:") {
					t.Fatalf("driver scan message lost: %q", body.Message)
				}
			} else if body.Message != tc.want {
				t.Fatalf("message=%q,want=%q", body.Message, tc.want)
			}
		})
	}
}
