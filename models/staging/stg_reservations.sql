with source as (
    select * from {{ source('nm_raw', 'raw_reservations') }}
),

mapped as (

    select
        *,

        -- Abbreviation code, not a descriptive label -- kept uppercase per
        -- convention (BB/HB/FB/AI/SC), unlike other string columns which are
        -- Capitalized. Mapping assumes standard hospitality meal-plan terms;
        -- verify against actual raw values and adjust the WHEN list if needed.
        case
            when meal_plan is null then 'SC'
            when upper(trim(meal_plan)) in ('BB', 'BED AND BREAKFAST', 'BED & BREAKFAST') then 'BB'
            when upper(trim(meal_plan)) in ('HB', 'HALF BOARD') then 'HB'
            when upper(trim(meal_plan)) in ('FB', 'FULL BOARD') then 'FB'
            when upper(trim(meal_plan)) in ('AI', 'ALL INCLUSIVE') then 'AI'
            when upper(trim(meal_plan)) in ('SC', 'SELF CATERING', 'ROOM ONLY') then 'SC'
            else upper(trim(meal_plan))
        end as meal_plan_code

    from source

),

cleaned as (

    select
        reservation_id,
        property_id,
        room_type_id,
        channel_category_id,

        booking_date,
        check_in_date,
        check_out_date,
        cancellation_date,

        datediff('day', check_in_date, check_out_date)  as nights_stayed,
        datediff('day', booking_date, check_in_date)    as lead_time_days,

        num_guests,

        meal_plan_code                                  as meal_plan,
        meal_plan_code in ('BB', 'HB', 'FB', 'AI')       as has_breakfast,

        initcap(trim(cancellation_policy))              as cancellation_policy,
        cancellation_deadline_days,

        case
            when upper(trim(status)) in ('NS', 'NO_SHOW', 'NO SHOW') then 'No_Show'
            when upper(trim(status)) = 'CONFIRMED'                   then 'Confirmed'
            when upper(trim(status)) = 'CANCELLED'                   then 'Cancelled'
            else trim(status)
        end                                             as status,
        case
            when upper(trim(status)) = 'CANCELLED'      then true
            else false
        end                                             as is_cancelled,

        total_amount,
        case
            when datediff('day', check_in_date, check_out_date) > 0
            then total_amount / datediff('day', check_in_date, check_out_date)
            else null
        end                                             as daily_rate

    from mapped

)

select * from cleaned
