-- Every reservation goes down exactly one of two paths: cancelled reservations
-- go straight to fct_cancellations from stg_reservations; non-cancelled ones
-- go through int_reservation_nights. This checks that split is complete and
-- non-overlapping -- a reservation should never go missing or get counted
-- twice across the two paths.
--
-- Fails (returns a row) if the total reservation count doesn't match the sum
-- of the two downstream paths.

with total as (

    select count(distinct reservation_id) as reservation_count
    from {{ ref('stg_reservations') }}

),

split as (

    select
        (select count(distinct reservation_id) from {{ ref('int_reservation_nights') }})
        + (select count(*) from {{ ref('fct_cancellations') }})    as reservation_count

)

select
    total.reservation_count  as total_reservations,
    split.reservation_count  as split_reservations

from total, split
where total.reservation_count != split.reservation_count
