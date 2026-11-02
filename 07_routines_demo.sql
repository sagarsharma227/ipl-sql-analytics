-- optional example of a reusable user-defined function.
-- run after importing the csv files. this file is not required for the core analysis.

create schema if not exists analytics;

create or replace function analytics.get_batter_summary(p_batsman text)
returns table (
    player_name text,
    total_runs bigint,
    balls_faced bigint,
    strike_rate numeric
)
language sql
stable
as $function$
    select
        min(d.batsman) as player_name,
        sum(d.batsman_runs) as total_runs,
        count(*) filter (where d.wide_runs = 0) as balls_faced,
        round(
            100.0 * sum(d.batsman_runs)
            / nullif(count(*) filter (where d.wide_runs = 0), 0),
            2
        ) as strike_rate
    from public.deliveries d
    where d.inning <= 2
      and lower(btrim(d.batsman)) = lower(btrim(p_batsman))
    group by lower(btrim(d.batsman));
$function$;

-- example call:
-- select * from analytics.get_batter_summary('sc ganguly');
