CREATE SEQUENCE %[1]s_id;
CREATE TABLE %[1]s (
    id BIGINT PRIMARY KEY DEFAULT nextval('%[1]s_id'),
    version BIGINT NOT NULL,
    applied_at TIMESTAMP NOT NULL DEFAULT current_timestamp
);
