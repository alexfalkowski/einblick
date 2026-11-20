-- +goose Up
CREATE SEQUENCE log_id;
CREATE TABLE log_resources (
    id BIGINT PRIMARY KEY DEFAULT nextval('log_id'),
    content JSON NOT NULL
);
CREATE TABLE log_scopes (
    id BIGINT PRIMARY KEY DEFAULT nextval('log_id'),
    resource_id BIGINT NOT NULL,
    content JSON NOT NULL
);
CREATE TABLE logs (
    id BIGINT PRIMARY KEY DEFAULT nextval('log_id'),
    scope_id BIGINT NOT NULL,
    timestamp_ns UBIGINT NOT NULL,
    observed_timestamp_ns UBIGINT NOT NULL,
    received_timestamp_ns UBIGINT NOT NULL,
    event_timestamp_ns UBIGINT NOT NULL,
    content JSON NOT NULL
);
