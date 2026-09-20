-- PROPOSAL ONLY - NOT APPLIED. Do not run until you have read
-- Documents/SUPABASE_SECURITY.md, section "Stop score cheating".
--
-- Problem: the phone writes profiles.current_score directly, so a cheater
-- can call the Supabase REST API with their own login and set any score.
-- This trigger is a cheap first line of defence: a logged-in player can no
-- longer change their score by more than max_delta in one update, and can
-- not stamp last_active_at in the future. (The service role - our Edge
-- Functions and the SQL editor - is exempt.)
--
-- Limits: it slows cheating, it does not prove a score was earned. Real
-- protection = move scoring into a server function (RPC), see the guide.
-- Tune max_delta: a very long Play session can legitimately add many
-- points (+4 per correct answer); 2000 = 500 correct answers in one update.

create or replace function public.guard_profile_update()
returns trigger
language plpgsql
security invoker
as $fn$
declare
  max_delta constant int := 2000;
begin
  -- auth.role() is 'service_role' for Edge Functions / dashboard - allow.
  if coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;

  if new.current_score is distinct from old.current_score
     and abs(new.current_score - old.current_score) > max_delta then
    raise exception 'score change too large' using errcode = '22023';
  end if;

  if new.last_active_at is not null
     and new.last_active_at > now() + interval '5 minutes' then
    raise exception 'invalid last_active_at' using errcode = '22023';
  end if;

  return new;
end;
$fn$;

drop trigger if exists profiles_guard_update on public.profiles;
create trigger profiles_guard_update
  before update on public.profiles
  for each row execute function public.guard_profile_update();
