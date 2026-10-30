# MySQL database objects

The object browser lists views, triggers, procedures, functions, scheduled events,
roles and users. Select a category and an object to inspect its full CREATE statement and
metadata. The read-only code viewer includes line numbers, horizontal scrolling
and a Copy SQL action. SQL is displayed with local whitespace formatting by
default: DDL clauses, event schedules and statement bodies use separate lines,
and BEGIN blocks are indented. Quoted strings, identifiers and comments are
protected from keyword formatting. Original SQL switches to the exact server
text; Copy SQL copies the currently displayed version. Incomplete quoted text
or comments fall back to the original definition. Backslash-containing strings
also use the original text when the object SQL mode is unknown. Formatting does not execute SQL. Accounts are server-wide, identified by both user name and host.
Definitions for views, triggers, procedures, functions and events come from
`SHOW CREATE`, preserving the server-reported declaration, parameters, definer,
schedule, options and body rather than displaying only the body. This is the
server's current definition, not a record of the original SQL text or subsequent
ALTER statements. The source is shown in metadata. When access is denied, an
object disappears, or a definition is hidden, the object remains listed with an
availability explanation; partial bodies are not presented as full definitions.
Depending on the object, metadata includes definer, SQL mode, timestamps,
schedule, time zone, completion behavior, comments and execution characteristics.
MySQL/MariaDB events are the supported scheduled jobs. PostgreSQL, `pg_cron` and
external operating-system cron jobs are not currently supported.

Definitions are fetched on demand when an object is selected, through
`GET /api/connections/{connId}/object-definition?type=…&name=…`, with a separate
ten-second timeout. Schema listings do not fetch DDL, so large schemas do not
issue one SHOW CREATE query per object. Definition failures leave the object
metadata available; failed requests can be retried from the detail view. Each metadata category is limited to 1,000 objects; schema
requests have a ten-second timeout.

MySQL 8 does not distinguish roles from users in a dedicated account-type field.
The optional administrator-installed `nichosi_account_metadata` view classifies
locked accounts without credentials as roles (including unassigned roles).
A locked passwordless user is consequently also shown as a role. The UI states
this classification. Roles show a reconstructed `CREATE ROLE` using only account name and host;
metadata explicitly marks it as reconstructed, without grants or creation history.
It is not a complete recreation script for the account's privileges. User creation
SQL is intentionally unavailable: `SHOW CREATE USER` is never requested because
it can expose authentication data. Authentication strings are never returned to Nichosi.
Without this view the remaining objects still load and the UI displays a warning
that users and roles are unavailable.

`deploy/mysql-demo-objects.sql` installs examples in the existing `nichosi_lab`
database. Run it as the local MySQL administrator and discard stdout, as MySQL
returns the randomly generated password for the locked demo user. Demo accounts
are restricted to localhost. The daily event is disabled and the global event
scheduler is not changed. Existing business tables are not modified.
The optional SQL SECURITY DEFINER metadata view exposes only account name, host,
lock status and inferred type; it grants no direct access to `mysql.user`.
The account creating the view must retain permission to read that system table.

For local integration tests, set `NICHOSI_TEST_DSN` through the environment and run
`go test ./internal/driver` from `backend/`. Tests skip when no local DSN is set.
