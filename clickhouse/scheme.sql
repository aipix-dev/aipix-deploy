CREATE DATABASE IF NOT EXISTS orchestrator;

CREATE TABLE IF NOT EXISTS orchestrator.events(
    message String,
    received_at DateTime DEFAULT now(),
    REC_DATE Date DEFAULT toDate(now())
)
ENGINE = MergeTree()
PARTITION BY REC_DATE
ORDER BY received_at
SETTINGS index_granularity = 8192;

CREATE TABLE IF NOT EXISTS orchestrator.analytic_case_events (
    `inner_data` String,
    `analytic_type` String,
    `analytic_case_uuid` String,
    `analytic_case_camera_uuid` String,
    `stream_uuid` String,
    `crop` Array(String),
    `event_frame_url` Nullable(String),
    `rect` Array(Array(UInt32)),
    `age`  Array(Float32),
    `fence_name`  Array(String),
    `container_code` Nested(
        code String,
        similarity Float32
    ),
    `container_dims_code` Nested(
        code String,
        similarity Float32
    ),
    `score` Array(Float64),
    `event_type` String,
    `is_recognized` UInt8,
    `license_plate` String,
    `resource_license_plates` Array(String),
    `matches` Nested(
        resource_uuid String,
        similarity Float32
    ),
    `received_at` DateTime,
    `created_at` DateTime DEFAULT `received_at`,
    `received_date` Date,
    `uuid` String
)
ENGINE = MergeTree()
PARTITION BY received_date
ORDER BY (analytic_case_camera_uuid, analytic_case_uuid, received_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS orchestrator.mv_analytic_case_events
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
    JSONExtract(inner_data, 'fenceName', 'Array(String)') AS fence_name,
    arrayMap(x -> (x.1), JSONExtract(inner_data, 'containerCode', 'Nested(code String, similarity Float32)')) as `container_code.code`,
    arrayMap(x -> (x.2), JSONExtract(inner_data, 'containerCode', 'Nested(code String, similarity Float32)')) as `container_code.similarity`,
    arrayMap(x -> (x.1), JSONExtract(inner_data, 'dimsCode', 'Nested(code String, similarity Float32)')) as `container_dims_code.code`,
    arrayMap(x -> (x.2), JSONExtract(inner_data, 'dimsCode', 'Nested(code String, similarity Float32)')) as `container_dims_code.similarity`,
    JSONExtract(inner_data, 'score', 'Array(Float64)') AS score,
    JSONExtractString(inner_data, 'type') AS event_type,
    JSONLength(inner_data, 'MatchResult') > 0 as is_recognized,
    arrayElement(JSONExtract(inner_data, 'licplateNumber', 'Array(String)'), 1) AS license_plate,
    arrayMap(x -> (x.3), JSONExtract(inner_data, 'MatchResult', 'Nested(resource_uuid String, similarity Float32, resource String)'))  as resource_license_plates,
    arrayMap(x -> (x.1), JSONExtract(inner_data, 'MatchResult', 'Nested(resource_uuid String, similarity Float32)'))  as `matches.resource_uuid`,
    arrayMap(x -> (x.2), JSONExtract(inner_data, 'MatchResult', 'Nested(resource_uuid String, similarity Float32)'))  as `matches.similarity`,
    received_at,
    fromUnixTimestamp64Milli(toInt64(JSONExtractUInt(inner_data, 'timestampMs')), 'UTC') AS created_at,
    REC_DATE AS received_date,
    toString( generateUUIDv4() ) as uuid
FROM orchestrator.events
WHERE
    JSONExtractString(message, 'channel') = 'events'
    AND (has(JSONExtract(inner_data, 'fenceSide', 'Array(String)'), 'left') OR NOT JSONHas(inner_data, 'fenceSide'));

CREATE TABLE IF NOT EXISTS orchestrator.visitor_countings (
    `analytic_type` String,
    `analytic_case_uuid` String,
    `analytic_case_camera_uuid` String,
    `stream_uuid` String,
    `age` Float32,
    `fence_name` String,
    `fence_side` String,
    `male_prob` Float32,
    `sex` String,
    `object_id` UInt32,
    `event_type` String,
    `event_frame_url` Nullable(String),
    `received_at` DateTime,
    `created_at` DateTime DEFAULT `received_at`,
    `received_date` Date
)
ENGINE = MergeTree()
PARTITION BY received_date
ORDER BY (analytic_case_uuid, received_at);

CREATE MATERIALIZED VIEW IF NOT EXISTS orchestrator.mv_visitor_countings
TO orchestrator.visitor_countings
AS
SELECT
    analytic_type,
    analytic_case_uuid,
    analytic_case_camera_uuid,
    stream_uuid,
    age,
    fence_name,
    fence_side,
    male_prob,
    if(
        male_prob >= 0.5,
        'male',
        if(male_prob = -1, 'unrecognized', 'female')
    ) as sex,
    object_id,
    event_type,
    event_frame_url,
    received_at,
    created_at,
    received_date
FROM
    orchestrator.analytic_case_events
    ARRAY JOIN
    JSONExtract(inner_data, 'age', 'Array(Float32)') as age,
    JSONExtract(inner_data, 'male_prob', 'Array(Float32)') AS male_prob,
    JSONExtract(inner_data, 'fenceName','Array(String)') as fence_name,
    JSONExtract(inner_data, 'fenceSide', 'Array(String)') as fence_side,
    JSONExtract(inner_data, 'objId', 'Array(UInt32)') as object_id
WHERE
    event_type = 'visitors-counting';
