-- Each Confirmed reservation's exploded night-rows in fct_reservation_nights
-- should number exactly num_nights. No_Show reservations deliberately emit
-- one check-in-date row only, representing Nova M's retained first-night
-- charge after which the remaining reservation is released. This catches any
-- date-spine boundary bug (e.g. a reservation whose check_in/check_out falls
-- outside the spine's computed range, silently dropping or truncating nights).
--
-- Fails (returns a row) for any reservation where the exploded row count
-- doesn't match its own num_nights value.

select
    reservation_id,
    num_nights,
    reservation_status,
    count(*) as exploded_nights

from {{ ref('fct_reservation_nights') }}
group by 1, 2, 3
having count(*) != case
    when reservation_status = 'No_Show' then 1
    else num_nights
end
