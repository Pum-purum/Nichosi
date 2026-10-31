package driver

import (
	"context"
	"database/sql"
	"errors"
	"fmt"
	"regexp"
)

var ErrViewNotFound = errors.New("view not found")
var viewAlgorithm = regexp.MustCompile(`(?i)\bALGORITHM\s*=\s*(UNDEFINED|MERGE|TEMPTABLE)\b`)

func MySQLViewMetadata(ctx context.Context, db *sql.DB, database, view string) (TableMetadata, error) {
	result := TableMetadata{Name: view, Details: map[string]string{}, Columns: []map[string]string{}, Indexes: []map[string]string{}, ForeignKeys: []map[string]string{}, Triggers: []map[string]string{}, Warnings: []string{}}
	// Object existence uses information_schema.tables so inaccessible view properties
	// do not masquerade as an absent view.
	var exists int
	if err := db.QueryRowContext(ctx, "SELECT COUNT(*) FROM information_schema.tables WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? AND TABLE_TYPE = 'VIEW'", database, view).Scan(&exists); err != nil {
		return result, fmt.Errorf("check view: %w", err)
	}
	if exists == 0 {
		return result, ErrViewNotFound
	}
	details, _, err := metadataRows(ctx, db, `SELECT SECURITY_TYPE AS Security, CHECK_OPTION AS "Check option", IS_UPDATABLE AS "Server updatable", DEFINER AS Definer, CHARACTER_SET_CLIENT AS "Character set client", COLLATION_CONNECTION AS "Collation connection" FROM information_schema.views WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? LIMIT 1`, database, view)
	if err != nil {
		if metadataPermissionError(err) {
			result.Warnings = append(result.Warnings, "View properties are unavailable to this account.")
		} else {
			return result, fmt.Errorf("read view properties: %w", err)
		}
	} else if len(details) > 0 {
		result.Details = details[0]
	} else {
		result.Warnings = append(result.Warnings, "View properties are unavailable to this account.")
	}
	result.Details["Access"] = "Read-only in Nichosi"
	columns, truncated, err := metadataRows(ctx, db, `SELECT ORDINAL_POSITION AS Position, COLUMN_NAME AS Name, COLUMN_TYPE AS Type, IS_NULLABLE AS Nullable, COLUMN_DEFAULT AS "Default", EXTRA AS Extra, CHARACTER_SET_NAME AS "Character set", COLLATION_NAME AS Collation, COLUMN_COMMENT AS Comment FROM information_schema.columns WHERE TABLE_SCHEMA = ? AND TABLE_NAME = ? ORDER BY ORDINAL_POSITION LIMIT 1001`, database, view)
	if err != nil {
		if metadataPermissionError(err) {
			result.Warnings = append(result.Warnings, "Columns metadata is unavailable to this account.")
		} else {
			return result, fmt.Errorf("read view columns: %w", err)
		}
	} else {
		result.Columns = columns
		if truncated {
			result.Warnings = append(result.Warnings, "Columns metadata is limited to 1000 entries.")
		}
	}
	object := Object{Name: view, Type: "view", Details: map[string]string{}}
	if err := mysqlObjectDefinition(ctx, db, database, &object); err != nil {
		if metadataPermissionError(err) || errors.Is(err, errDefinitionUnavailable) {
			result.Warnings = append(result.Warnings, "CREATE VIEW is unavailable to this account.")
		} else {
			return result, fmt.Errorf("read view definition: %w", err)
		}
	} else {
		result.Definition = object.Definition
		if matches := viewAlgorithm.FindStringSubmatch(object.Definition); len(matches) > 1 {
			result.Details["Algorithm"] = matches[1]
		}
	}
	return result, nil
}
