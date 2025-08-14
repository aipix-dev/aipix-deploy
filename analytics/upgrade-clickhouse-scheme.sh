#!/bin/bash

#Create backup tables
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "RENAME TABLE orchestrator.events TO orchestrator.events_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT count() FROM orchestrator.events_old;"

kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "RENAME TABLE orchestrator.mv_analytic_case_events TO orchestrator.mv_analytic_case_events_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT count() FROM orchestrator.mv_analytic_case_events_old;"

kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "RENAME TABLE orchestrator.analytic_case_events TO orchestrator.analytic_case_events_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT count() FROM orchestrator.analytic_case_events_old;"

kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "RENAME TABLE orchestrator.visitor_countings TO orchestrator.visitor_countings_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT count() FROM orchestrator.visitor_countings_old;"

#Create new tables
kubectl -n ${NS_A} exec deployments/clickhouse-server -- sh -c 'clickhouse-client < /docker-entrypoint-initdb.d/scheme.sql'

#Check new tables exist
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SHOW TABLES FROM orchestrator;"

#Edit old tables
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "ALTER TABLE orchestrator.analytic_case_events_old ADD COLUMN age Array(Float32), ADD COLUMN fence_name Array(String);"

#Copy data from old tables into new
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client --multiquery "INSERT INTO orchestrator.analytic_case_events (
    inner_data,
    analytic_type,
    analytic_case_uuid,
    analytic_case_camera_uuid,
    stream_uuid,
    crop,
    event_frame_url,
    rect,
    age,
    fence_name,
    \`container_code.code\`,
    \`container_code.similarity\`,
    \`container_dims_code.code\`,
    \`container_dims_code.similarity\`,
    score,
    event_type,
    is_recognized,
    license_plate,
    resource_license_plates,
    \`matches.resource_uuid\`,
    \`matches.similarity\`,
    received_at,
    created_at,
    received_date,
    uuid
)
SELECT
    inner_data,
    analytic_type,
    analytic_case_uuid,
    analytic_case_camera_uuid,
    stream_uuid,
    crop,
    event_frame_url,
    rect,
    age,
    fence_name,
    \`container_code.code\`,
    \`container_code.similarity\`,
    \`container_dims_code.code\`,
    \`container_dims_code.similarity\`,
    score,
    event_type,
    is_recognized,
    license_plate,
    resource_license_plates,
    \`matches.resource_uuid\`,
    \`matches.similarity\`,
    received_at,
    created_at,
    received_date,
    uuid
FROM orchestrator.analytic_case_events_old;"

kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "INSERT INTO orchestrator.visitor_countings SELECT * FROM orchestrator.visitor_countings_old;"

#Check rows quantity
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT COUNT() FROM orchestrator.analytic_case_events;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT COUNT() FROM orchestrator.analytic_case_events_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT COUNT() FROM orchestrator.visitor_countings;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT COUNT() FROM orchestrator.visitor_countings_old;"

#Update new columns
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client --multiquery "ALTER TABLE orchestrator.analytic_case_events
UPDATE
    age = JSONExtract(inner_data, 'age', 'Array(Float32)'),
    fence_name = JSONExtract(inner_data, 'fenceName', 'Array(String)')
WHERE
    fence_name = [] AND
    age = [];"

#Check events and delete unused
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT count() FROM orchestrator.analytic_case_events WHERE has(JSONExtract(inner_data, 'fenceSide', 'Array(String)'), 'right');"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "ALTER TABLE orchestrator.analytic_case_events DELETE WHERE has(JSONExtract(inner_data, 'fenceSide', 'Array(String)'), 'right');"

#Check deletion
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "SELECT count() FROM orchestrator.analytic_case_events WHERE has(JSONExtract(inner_data, 'fenceSide', 'Array(String)'), 'right');"

#Run optimization
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "OPTIMIZE TABLE orchestrator.analytic_case_events FINAL;"

#Drop old tables
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "DROP TABLE IF EXISTS orchestrator.events_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "DROP TABLE IF EXISTS orchestrator.analytic_case_events_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "DROP TABLE IF EXISTS orchestrator.visitor_countings_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "DROP TABLE IF EXISTS orchestrator.mv_analytic_case_events_old;"
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "DROP TABLE IF EXISTS orchestrator.buffer_events"
