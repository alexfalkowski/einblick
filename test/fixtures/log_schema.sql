-- Reset the disposable feature database's application schema and history.
DROP TABLE logs;
DROP TABLE log_scopes;
DROP TABLE log_resources;
DROP SEQUENCE log_id;
DROP TABLE goose_db_version;
DROP SEQUENCE goose_db_version_id;
CREATE TABLE log_migration_probe (marker VARCHAR);
INSERT INTO log_migration_probe VALUES ('preserved');
