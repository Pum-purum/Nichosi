# MySQL database objects

The object browser lists views, triggers, procedures, functions, scheduled events,
roles and users. Category badges and list headings display the object count
whenever it is at least one; empty categories have no count badge. Select a category and an object to inspect its full CREATE statement.
The detail panel starts with the object name and SQL, without a decorative icon,
repeated category label or separate metadata grid. The read-only code viewer includes line numbers, horizontal scrolling
and an icon-only Copy SQL action in the top-right corner of the code panel.
The copy button appears on hover or keyboard focus, and stays visible on touch
devices. Highlight.js supplies local SQL syntax highlighting for
keywords, strings, numbers, comments and built-in types/functions, using the
core and SQL grammar only. The library is bundled with the application; no CDN
or runtime network request is used. Copy SQL copies plain executable SQL, compacted to a single line by collapsing
whitespace between tokens and removing ordinary comments. Executable MySQL/MariaDB
comments and optimizer hints are retained. Whitespace inside quoted values and
identifiers remains unchanged, including literal newlines; ambiguous quoting
falls back to the exact server text to avoid changing SQL semantics. SQL keywords and operators use a fixed blue accent. SQL is displayed with local whitespace formatting by
default: DDL clauses, event schedules and statement bodies use separate lines,
and related clauses are indented by two spaces per level. Schedule details nest
under ON SCHEDULE, event statements nest under DO, query expressions nest under
SELECT/FROM/WHERE/SET, and nested BEGIN blocks and subqueries gain their own level. Quoted strings, identifiers and comments are
protected from keyword formatting. The viewer keeps its readable formatting while copying uses the compact
server definition; there is no original-text toggle. Incomplete quoted text
or comments fall back to the original definition. Backslash-containing strings
also use the original text when the object SQL mode is unknown. Formatting does not execute SQL. Accounts are server-wide, identified by both user name and host. Account labels
and filtering use the plain account name and host (for example, root@localhost),
without SQL quoting. Object identity and SQL definitions retain their original quoting.
Definitions for views, triggers, procedures, functions and events come from
`SHOW CREATE`, preserving the server-reported declaration, parameters, definer,
schedule, options and body rather than displaying only the body. This is the
server's current definition, not a record of the original SQL text or subsequent
ALTER statements. When access is denied, an
object disappears, or a definition is hidden, the object remains listed with an
availability explanation; partial bodies are not presented as full definitions.
The API retains object metadata for formatting and availability handling;
the detail panel omits fields already represented by the CREATE statement.
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
a short note marks it as reconstructed, without grants or creation history.
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
