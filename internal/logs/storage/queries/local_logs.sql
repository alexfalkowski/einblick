SELECT l.id, l.event_timestamp_ns, l.received_timestamp_ns,
       r.content::VARCHAR AS resource, s.content::VARCHAR AS scope,
       l.content::VARCHAR AS record, '' AS source
FROM logs l
JOIN log_scopes s ON s.id = l.scope_id
JOIN log_resources r ON r.id = s.resource_id
