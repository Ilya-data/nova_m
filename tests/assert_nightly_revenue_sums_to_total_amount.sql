-- For Confirmed reservations, nightly_revenue is documented as additive
-- (total_amount allocated evenly across nights), so summing it back up per
-- reservation should reconstruct the reservation's total_amount. No_Show
-- reservations deliberately retain only their first-night charge, so they
-- are excluded from this full-reservation reconciliation.
--
-- Fails (returns a row) for any reservation where the two disagree by more
-- than a rounding tolerance. nightly_revenue is rounded to 2 decimals per
-- night, so up to ~0.5 cent of drift can accumulate per night -- the
-- tolerance scales with nights_stayed (1 cent/night) to account for that
-- rather than using a single flat threshold that's too tight for long stays.

with by_reservation as (

    select
        reservation_id,
        sum(nightly_revenue) as summed_revenue

    from {{ ref('fct_reservation_nights') }}
    group by 1

)

select
    r.reservation_id,
    r.total_amount,
    b.summed_revenue,
    r.nights_stayed

from {{ ref('stg_reservations') }} r
inner join by_reservation b using (reservation_id)
where r.status = 'Confirmed'
  and abs(r.total_amount - b.summed_revenue) > (0.01 * r.nights_stayed)
