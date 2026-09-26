-- Reservation-nights fact table, enriched beyond int_reservation_nights with
-- presentation-layer derivations: arrival/departure flags, peak-season flag
-- (needs dim_property, hence done here rather than intermediate), a
-- friendly weekday/weekend label, lead-time bucketing, and revenue naming
-- clarified for correct BI aggregation (see nightly_revenue below).

with int_nights as (

    select * from {{ ref('int_reservation_nights') }}

),

enriched as (

    select
        n.reservation_id,
        n.stay_date,
        n.property_id,
        n.room_type_id,
        n.channel_id,

        -- Renamed from nightly_rate: for Confirmed reservations, this is
        -- total_amount allocated evenly across nights, i.e. additive (SUM
        -- gives reservation total_amount back). A No_Show emits its retained
        -- first-night charge only. "Rate" invites the wrong aggregation in
        -- BI tools -- "revenue" doesn't.
        round(n.nightly_rate, 2)                                            as nightly_revenue,

        n.num_guests,
        n.num_nights,

        n.lead_time_days,
        case
            when n.lead_time_days <= 7  then '0-7 days'
            when n.lead_time_days <= 30 then '8-30 days'
            when n.lead_time_days <= 90 then '31-90 days'
            else '90+ days'
        end                                                                 as lead_time_bucket,

        n.meal_plan,
        n.booking_channel,
        n.property_name,
        n.country,
        n.room_type_name,

        n.stay_month,
        n.day_of_week,
        n.is_weekend,
        case when n.is_weekend then 'Weekend' else 'Weekday' end            as day_type,

        -- Arrival/departure flags: only meaningful post-explosion, so this
        -- is a mart-level enrichment, not intermediate's job.
        n.stay_date = min(n.stay_date) over (partition by n.reservation_id) as is_arrival_night,
        n.stay_date = max(n.stay_date) over (partition by n.reservation_id) as is_departure_night,

        {{ is_peak_season('p.seasonality', 'n.stay_date') }}                as is_peak_season,

        n.reservation_status

    from int_nights n
    left join {{ ref('dim_property') }} p on p.property_id = n.property_id

)

select * from enriched
