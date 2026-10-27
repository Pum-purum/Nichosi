# MySQL database objects

The object browser lists views, triggers, procedures, functions, scheduled events,
roles and users. Select a category and an object to inspect its SQL body and
metadata. Accounts are server-wide, identified by both user name and host.
SQL bodies are read-only and may be unavailable when MySQL hides them from the
connected account. Each metadata category is limited to 1,000 objects; schema
requests have a ten-second timeout.

MySQL 8 does not distinguish roles from users in a dedicated account-type field.
The optional administrator-installed `nichosi_account_metadata` view classifies
locked accounts without credentials as roles (including unassigned roles).
A locked passwordless user is consequently also shown as a role. The UI states
this classification. Authentication strings are never returned to Nichosi.
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
