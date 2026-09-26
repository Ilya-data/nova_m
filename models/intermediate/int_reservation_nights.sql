-- Explodes each non-cancelled reservation into one row per stay night
-- (check_out_date is exclusive, i.e. not itself a stay night), and joins in
-- property/room type/channel descriptors so marts don't need to.
--
-- Cancelled reservations are excluded entirely here -- they go straight to
-- fct_cancellations from stg_reservations instead.

with reservations as (

    select *
    from {{ ref('stg_reservations') }}
    where not is_cancelled  -- keeps Confirmed + No_Show, drops Cancelled

),

-- Bounds computed from the full stg_reservations table (unfiltered), which
-- is a superset of the filtered range above. See macros/date_spine_bound.sql
-- for why this can't just reference the "reservations" CTE by name.
date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date=date_spine_bound('min', ref('stg_reservations'), 'check_in_date'),
        end_date=date_spine_bound('max', ref('stg_reservations'), 'check_out_date')
    ) }}
),

nights as (

    select
        r.reservation_id,
        ds.date_day                as stay_date,
        r.property_id,
        r.room_type_id,
        r.channel_category_id      as channel_id,
        r.daily_rate                as nightly_rate,
        r.num_guests,
        r.nights_stayed            as num_nights,
        r.lead_time_days,
        r.meal_plan,
        r.status                   as reservation_status

    from reservations r
    inner join date_spine ds
        on ds.date_day >= r.check_in_date
       and ds.date_day <  r.check_out_date

),

enriched as (

    select
        n.reservation_id,
        n.stay_date,
        n.property_id,
        n.room_type_id,
        n.channel_id,
        n.nightly_rate,
        n.num_guests,
        n.num_nights,
        n.lead_time_days,
        n.meal_plan,
        ch.channel_category        as booking_channel,
        p.property_name,
        p.country,
        rt.room_type_name,

        date_trunc('month', n.stay_date)          as stay_month,
        dayname(n.stay_date)                      as day_of_week,
        dayname(n.stay_date) in ('Sat', 'Sun')     as is_weekend,

        n.reservation_status

    from nights n
    left join {{ ref('stg_properties') }} p  on p.property_id       = n.property_id
    left join {{ ref('stg_room_types') }} rt on rt.room_type_id     = n.room_type_id
    left join {{ ref('stg_channels') }}   ch on ch.channel_category_id = n.channel_id

)

select * from enriched
