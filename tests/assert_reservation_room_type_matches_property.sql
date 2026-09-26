-- A reservation's room type must belong to the reservation's property. The
-- individual foreign-key tests cannot detect a valid room_type_id belonging
-- to a different valid property.

select
    r.reservation_id,
    r.property_id,
    r.room_type_id

from {{ ref('stg_reservations') }} r
left join {{ ref('stg_room_types') }} rt
    on rt.property_id = r.property_id
   and rt.room_type_id = r.room_type_id
where rt.room_type_id is null
