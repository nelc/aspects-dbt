{{ config(
    materialized='materialized_view',
    schema=env_var('ASPECTS_XAPI_DATABASE', 'xapi'),
    engine=get_engine('ReplacingMergeTree()'),
    primary_key='(org, course_key, object_type)',
    order_by='(org, course_key, object_type, emission_time, actor_id, starting_position, event_id)',
    partition_by='(toYYYYMM(emission_time))',
  ) }}

SELECT
    event_id,
    cast(emission_time as DateTime) as emission_time,
    actor_id,
    splitByString('/xblock/', object_id)[-1] as block_id,
    splitByString('/', course_id)[-1] AS course_key,
    org,
    verb_id,
    JSONExtractString(event, 'object', 'definition', 'type') AS object_type,
    -- clicking a link and selecting a module outline have no starting-position field
    if (
        object_type in (
            'http://adlnet.gov/expapi/activities/link',
            'http://adlnet.gov/expapi/activities/module'
        ),
        0,
        JSONExtractInt(
            event,
            'context', 'extensions', 'http://id.tincanapi.com/extension/starting-position'
        )
    ) AS starting_position,
    JSONExtractString(
        event,
        'context', 'extensions', 'http://id.tincanapi.com/extension/ending-point'
    ) AS ending_point
FROM
    {{ ref('xapi_events_all_parsed') }}
WHERE verb_id IN (
    'https://w3id.org/xapi/dod-isd/verbs/navigated'
)
