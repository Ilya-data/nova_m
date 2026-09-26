-- Capacity is capped at zero for reporting resilience, but maintenance blocks
-- must not collectively exceed the physical inventory of a room type.

select
    property_id,
    room_type_id,
    capacity_date,
    room_count,
    rooms_blocked

from {{ ref('fct_capacity_daily') }}
where rooms_blocked > room_count
