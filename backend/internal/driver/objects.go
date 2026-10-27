package driver

import (
	"context"
	"database/sql"
	"fmt"
	"strings"
)

// Object contains safe metadata only; account authentication data is never returned.
type Object struct {
	Name, Type, Definition string
	Details                map[string]string
}

// MySQLObjects reads schema objects and server-wide accounts with a bounded result size.
// Account metadata uses an administrator-provided view exposing non-secret fields only.
func MySQLObjects(ctx context.Context, db *sql.DB, database string) ([]Object, []string, error) {
	result := []Object{}
	warnings := []string{}
	queries := []struct {
		query  string
		args   []any
		kind   string
		labels []string
	}{
		{`SELECT TABLE_NAME, VIEW_DEFINITION, SECURITY_TYPE, CHECK_OPTION FROM information_schema.views WHERE TABLE_SCHEMA = ? ORDER BY TABLE_NAME LIMIT 1001`, []any{database}, "view", []string{"Security", "Check option"}},
		{`SELECT TRIGGER_NAME, ACTION_STATEMENT, EVENT_MANIPULATION, EVENT_OBJECT_TABLE, ACTION_TIMING FROM information_schema.triggers WHERE TRIGGER_SCHEMA = ? ORDER BY TRIGGER_NAME LIMIT 1001`, []any{database}, "trigger", []string{"Event", "Table", "Timing"}},
		{`SELECT ROUTINE_NAME, ROUTINE_DEFINITION, ROUTINE_TYPE, DTD_IDENTIFIER, IS_DETERMINISTIC, SECURITY_TYPE FROM information_schema.routines WHERE ROUTINE_SCHEMA = ? ORDER BY ROUTINE_NAME LIMIT 1001`, []any{database}, "routine", []string{"Routine type", "Returns", "Deterministic", "Security"}},
		{`SELECT EVENT_NAME, EVENT_DEFINITION, STATUS, EVENT_TYPE, INTERVAL_VALUE, INTERVAL_FIELD, CAST(EXECUTE_AT AS CHAR), CAST(STARTS AS CHAR), CAST(ENDS AS CHAR), TIME_ZONE FROM information_schema.events WHERE EVENT_SCHEMA = ? ORDER BY EVENT_NAME LIMIT 1001`, []any{database}, "event", []string{"Status", "Schedule", "Interval", "Unit", "Execute at", "Starts", "Ends", "Time zone"}},
		{`SELECT CONCAT(QUOTE(account_name), '@', QUOTE(account_host)), '', account_type, account_locked FROM ` + QuoteIdent(database) + `.nichosi_account_metadata ORDER BY account_name, account_host LIMIT 1001`, nil, "account", []string{"Account type", "Locked"}},
	}
	for _, q := range queries {
		rows, err := db.QueryContext(ctx, q.query, q.args...)
		if err != nil && q.kind == "account" {
			warnings = append(warnings, "Users and roles unavailable: ask an administrator to install the safe nichosi_account_metadata view.")
			continue
		}
		if err != nil {
			return nil, nil, fmt.Errorf("read %s metadata: %w", q.kind, err)
		}
		count := 0
		for rows.Next() {
			count++
			if count > 1000 {
				warnings = append(warnings, fmt.Sprintf("%s metadata is limited to 1000 objects.", q.kind))
				break
			}
			values := make([]sql.NullString, 2+len(q.labels))
			dest := make([]any, len(values))
			for i := range values {
				dest[i] = &values[i]
			}
			if err := rows.Scan(dest...); err != nil {
				rows.Close()
				return nil, nil, err
			}
			object := Object{Name: values[0].String, Type: q.kind, Definition: values[1].String, Details: map[string]string{}}
			for i, label := range q.labels {
				if values[i+2].Valid {
					object.Details[label] = values[i+2].String
				}
			}
			if q.kind == "routine" {
				if values[2].String == "FUNCTION" {
					object.Type = "function"
				} else {
					object.Type = "procedure"
				}
			}
			if q.kind == "account" {
				object.Type = values[2].String
				object.Details["Classification"] = "Locked accounts without credentials are shown as roles"
			}
			result = append(result, object)
		}
		err = rows.Err()
		rows.Close()
		if err != nil {
			return nil, nil, err
		}
	}
	return result, warnings, nil
}

// QuoteIdent quotes a MySQL identifier.
func QuoteIdent(name string) string { return "`" + strings.ReplaceAll(name, "`", "``") + "`" }
