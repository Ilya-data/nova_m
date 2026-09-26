-- A maintenance block's room type must belong to its property. This validates
-- the composite business key used by daily capacity calculations.

select
    m.maintenance_block_id,
    m.property_id,
    m.room_type_id

from {{ ref('stg_maintenance') }} m
left join {{ ref('stg_room_types') }} rt
    on rt.property_id = m.property_id
   and rt.room_type_id = m.room_type_id
where rt.room_type_id is null
