-- psql -X -v ON_ERROR_STOP=1 -f this-file in an empty disposable database only.
\set ON_ERROR_STOP on
CREATE ROLE anon;
CREATE ROLE authenticated;
CREATE ROLE service_role BYPASSRLS;
\ir catalog_write_permissions.sql
