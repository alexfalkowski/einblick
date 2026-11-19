-- A synthetic table-name conflict makes the final CREATE TABLE fail after
-- resources, scopes and their sequence are created in the migration transaction.
CREATE TABLE logs (marker VARCHAR);
INSERT INTO logs VALUES ('preserved');
