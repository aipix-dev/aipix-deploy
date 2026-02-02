#!/bin/bash

#Add new columns
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client --multiquery "ALTER TABLE orchestrator.analytic_case_events
    ADD COLUMN IF NOT EXISTS \`labels\` Array(String) AFTER \`age\`,
    ADD COLUMN IF NOT EXISTS \`classes\` Array(String) AFTER \`labels\`,
    ADD COLUMN IF NOT EXISTS \`label\` String AFTER \`classes\`,
    ADD COLUMN IF NOT EXISTS \`area_name\` String  AFTER \`label\`,
    MODIFY COLUMN \`fence_name\` Array(String) AFTER \`area_name\`,
    ADD COLUMN IF NOT EXISTS \`licplate_country_code\` Array(String) AFTER \`resource_license_plates\`;"

#Update new columns
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client --multiquery "ALTER TABLE orchestrator.analytic_case_events
UPDATE
    labels = if(
        JSONHas(inner_data, 'labels'),
        JSONExtract(inner_data, 'labels', 'Array(String)'),
        labels
    ),
    classes = if(
        JSONHas(inner_data, 'classes'),
        JSONExtract(inner_data, 'classes', 'Array(String)'),
        classes
    ),
    label = if(
        JSONHas(inner_data, 'label'),
        JSONExtractString(inner_data, 'label'),
        label
    ),
    area_name = if(
        JSONHas(inner_data, 'areaName'),
        JSONExtractString(inner_data, 'areaName'),
        area_name
    ),
    licplate_country_code = if(
        JSONHas(inner_data, 'licplateCountryCode'),
        JSONExtract(inner_data, 'licplateCountryCode', 'Array(String)'),
        licplate_country_code
    )
WHERE
    empty(labels)
    OR empty(classes)
    OR label = ''
    OR area_name = ''
    OR length(licplate_country_code) = 0;"

#Delete old materialized view
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "DROP TABLE orchestrator.mv_analytic_case_events"

#Create new materialized view
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client --multiquery "CREATE MATERIALIZED VIEW IF NOT EXISTS orchestrator.mv_analytic_case_events  
TO orchestrator.analytic_case_events  
AS  
SELECT
    JSONExtractRaw(JSONExtractRaw(message, 'data'), 'data') AS inner_data,  
    JSONExtractString(inner_data, 'AnalyticsType') AS analytic_type,  
    JSONExtractString(inner_data, 'CameraGroupUid') AS analytic_case_uuid,  
    JSONExtractString(inner_data, 'JobUid') AS analytic_case_camera_uuid,  
    JSONExtractString(inner_data, 'StreamUid') AS stream_uuid,  
    JSONExtract(inner_data, 'crop', 'Array(String)') AS crop,  
    JSONExtractString(inner_data, 'eventFrameUrl') AS event_frame_url,  
    JSONExtract(inner_data, 'rect', 'Array(Array(UInt32))') AS rect,  
    JSONExtract(inner_data, 'age', 'Array(Float32)') AS age,  
    JSONExtract(inner_data, 'labels',  'Array(String)') AS labels,  
    JSONExtract(inner_data, 'classes', 'Array(String)') AS classes,  
    JSONExtractString(inner_data, 'label')              AS label,  
    JSONExtractString(inner_data, 'areaName')           AS area_name,  
    JSONExtract(inner_data, 'fenceName', 'Array(String)') AS fence_name,  
    arrayMap(x -> (x.1), JSONExtract(inner_data, 'containerCode', 'Nested(code String, similarity Float32)')) as \`container_code.code\`,  
    arrayMap(x -> (x.2), JSONExtract(inner_data, 'containerCode', 'Nested(code String, similarity Float32)')) as \`container_code.similarity\`,  
    arrayMap(x -> (x.1), JSONExtract(inner_data, 'dimsCode', 'Nested(code String, similarity Float32)')) as \`container_dims_code.code\`,  
    arrayMap(x -> (x.2), JSONExtract(inner_data, 'dimsCode', 'Nested(code String, similarity Float32)')) as \`container_dims_code.similarity\`,  
    JSONExtract(inner_data, 'score', 'Array(Float64)') AS score,  
    JSONExtractString(inner_data, 'type') AS event_type,
    JSONLength(inner_data, 'MatchResult') > 0 as is_recognized,  
    arrayElement(JSONExtract(inner_data, 'licplateNumber', 'Array(String)'), 1) AS license_plate,  
    arrayMap(x -> (x.3), JSONExtract(inner_data, 'MatchResult', 'Nested(resource_uuid String, similarity Float32, resource String)')) as resource_license_plates,  
    JSONExtract(inner_data, 'licplateCountryCode', 'Array(String)') AS licplate_country_code,  
    arrayMap(x -> (x.1), JSONExtract(inner_data, 'MatchResult', 'Nested(resource_uuid String, similarity Float32)')) as \`matches.resource_uuid\`,  
    arrayMap(x -> (x.2), JSONExtract(inner_data, 'MatchResult', 'Nested(resource_uuid String, similarity Float32)')) as \`matches.similarity\`,  
    received_at,  
    fromUnixTimestamp64Milli(toInt64(JSONExtractUInt(inner_data, 'timestampMs')), 'UTC') AS created_at,  
    REC_DATE AS received_date,  
    toString(generateUUIDv4()) as uuid
FROM orchestrator.events  
WHERE  
    (has(JSONExtract(inner_data, 'fenceSide', 'Array(String)'), 'left') OR NOT JSONHas(inner_data, 'fenceSide'));"

#Check tables
kubectl -n ${NS_A} exec deployments/clickhouse-server -- clickhouse-client -q "show tables from orchestrator;"
