-- Daily available-room capacity per property x room type, net of maintenance
-- blocks. Grain: one row per property_id + room_type_id + capacity_date.
-- fct_capacity_daily enriches this at the same daily grain -- weekly and
-- monthly rollups happen in Tableau via dim_date, not by pre-aggregating
-- here.
--
-- rooms_blocked is capped at room_count so available_rooms never goes
-- negative, even if overlapping maintenance blocks over-report blocked rooms
-- on a given day.

with room_types as (

    select * from {{ ref('stg_room_types') }}

),

maintenance as (

    select * from {{ ref('stg_maintenance') }}

),

-- Bounds are the union of the reservation and maintenance date ranges. The
-- UNION ALL makes each bound null-safe when either source is empty. These are
-- scalar subqueries over real relations because dbt_utils.date_spine cannot
-- resolve an earlier CTE in its generated SQL.
date_spine as (
    {{ dbt_utils.date_spine(
        datepart="day",
        start_date="(select min(bound_date) from (select check_in_date as bound_date from " ~ ref('stg_reservations') ~ " where check_in_date is not null union all select start_date as bound_date from " ~ ref('stg_maintenance') ~ " where start_date is not null) as start_bounds)",
        end_date="(select max(bound_date) from (select check_out_date as bound_date from " ~ ref('stg_reservations') ~ " where check_out_date is not null union all select end_date as bound_date from " ~ ref('stg_maintenance') ~ " where end_date is not null) as end_bounds)"
    ) }}
),

room_days as (

    select
        rt.property_id,
        rt.room_type_id,
        rt.room_count,
        ds.date_day     as capacity_date

    from room_types rt
    cross join date_spine ds

),

blocked as (

    select
        m.property_id,
        m.room_type_id,
        ds.date_day                        as capacity_date,
        sum(m.rooms_out_of_service)        as rooms_blocked

    from maintenance m
    inner join date_spine ds
        on ds.date_day >= m.start_date
       and ds.date_day <  m.end_date
    group by 1, 2, 3

),

final as (

    select
        rd.property_id,
        p.property_name,
        p.country,
        rd.room_type_id,
        rt.room_type_name,
        rd.capacity_date,
        rd.room_count,
        coalesce(b.rooms_blocked, 0)                                        as rooms_blocked,
        rd.room_count - least(coalesce(b.rooms_blocked, 0), rd.room_count)  as available_rooms

    from room_days rd
    left join blocked b
        on b.property_id   = rd.property_id
       and b.room_type_id  = rd.room_type_id
       and b.capacity_date = rd.capacity_date
    left join {{ ref('stg_properties') }} p  on p.property_id  = rd.property_id
    left join {{ ref('stg_room_types') }} rt on rt.room_type_id = rd.room_type_id

)

select * from final
