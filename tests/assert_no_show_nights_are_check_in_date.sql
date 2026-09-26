-- Nova M retains a No_Show reservation as exactly one first-night charge.
-- The resulting reservation-night row must therefore be on check_in_date,
-- not another date in the original booking window.
--
-- Fails (returns a row) for any no-show fact row that is not on its scheduled
-- check-in date.

select
    f.reservation_id,
    f.stay_date,
    r.check_in_date

from {{ ref('fct_reservation_nights') }} f
inner join {{ ref('stg_reservations') }} r using (reservation_id)
where f.reservation_status = 'No_Show'
  and f.stay_date != r.check_in_date
