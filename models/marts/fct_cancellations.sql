-- Cancelled reservations only, at reservation grain. Sourced directly from
-- stg_reservations (no intermediate needed -- already at the right grain).
-- Note: this mart holds ONLY cancelled rows; computing cancellation_rate
-- requires a total-reservations count from elsewhere (e.g.
-- fct_reservation_nights' distinct reservation_id count for non-cancelled
-- reservations, combined with this mart's count for cancelled ones).

with cancelled as (

    select * from {{ ref('stg_reservations') }}
    where is_cancelled

)

select
    c.reservation_id,
    c.property_id,
    p.property_name,
    p.country,
    c.room_type_id,
    rt.room_type_name,
    c.channel_category_id      as channel_id,
    ch.channel_category        as booking_channel,

    c.booking_date,
    c.check_in_date,
    c.check_out_date,
    c.cancellation_date,
    c.lead_time_days,

    c.cancellation_policy,
    c.cancellation_deadline_days,

    c.status,
    c.total_amount

from cancelled c
left join {{ ref('stg_properties') }} p  on p.property_id       = c.property_id
left join {{ ref('stg_room_types') }} rt on rt.room_type_id     = c.room_type_id
left join {{ ref('stg_channels') }}   ch on ch.channel_category_id = c.channel_category_id
