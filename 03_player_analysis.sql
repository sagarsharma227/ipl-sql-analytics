-- player analysis using aggregates, conditional counts, statistical functions and window rankings.
-- standard batting and bowling metrics exclude innings greater than two.

-- 1. top three run scorers in each season. ties can result in more than three rows per season.
with season_calendar as (
    select season, min(date) as season_start
    from public.matches
    group by season
),
season_runs as (
    select
        m.season,
        d.batsman,
        sum(d.batsman_runs) as runs
    from public.deliveries d
    join public.matches m
        on m.match_id = d.match_id
    where d.inning <= 2
      and d.batsman is not null
    group by m.season, d.batsman
),
ranked_batters as (
    select
        sr.season,
        sc.season_start,
        sr.batsman,
        sr.runs,
        dense_rank() over (partition by sr.season order by sr.runs desc) as season_rank
    from season_runs sr
    join season_calendar sc
        on sc.season = sr.season
)
select season, batsman, runs, season_rank
from ranked_batters
where season_rank <= 3
order by season_start, season_rank, batsman;

-- 2. career run leaders with at least 500 balls faced.
-- a no-ball counts as a ball faced; a wide does not.
select
    batsman,
    sum(batsman_runs) as runs,
    count(*) filter (where wide_runs = 0) as balls_faced,
    round(
        100.0 * sum(batsman_runs)
        / nullif(count(*) filter (where wide_runs = 0), 0),
        2
    ) as strike_rate
from public.deliveries
where inning <= 2
group by batsman
having count(*) filter (where wide_runs = 0) >= 500
order by runs desc
limit 20;

-- 3. highest strike rates with at least 100 balls faced.
select
    batsman,
    sum(batsman_runs) as runs,
    count(*) filter (where wide_runs = 0) as balls_faced,
    round(
        100.0 * sum(batsman_runs)
        / nullif(count(*) filter (where wide_runs = 0), 0),
        2
    ) as strike_rate,
    case
        when sum(batsman_runs) >= 1000 then '1000+ runs'
        else 'under 1000 runs'
    end as career_run_band
from public.deliveries
where inning <= 2
group by batsman
having count(*) filter (where wide_runs = 0) >= 100
order by strike_rate desc, runs desc
limit 20;

-- 4. bowlers with the most wickets credited to them.
-- run outs, retired dismissals and obstructing the field are not credited as bowler wickets.
select
    bowler,
    count(*) filter (
        where dismissal_kind in ('bowled', 'caught', 'caught and bowled', 'lbw', 'stumped', 'hit wicket')
    ) as bowler_credited_wickets
from public.deliveries
where inning <= 2
group by bowler
order by bowler_credited_wickets desc, bowler
limit 20;

-- 5. best bowling economy for bowlers with at least 300 legal balls.
-- byes, leg-byes and penalty runs are not charged to the bowler.
with bowler_stats as (
    select
        bowler,
        sum(batsman_runs + extras - bye_runs - legbye_runs - penalty_runs) as runs_conceded,
        count(*) filter (where wide_runs = 0 and noball_runs = 0) as legal_balls
    from public.deliveries
    where inning <= 2
    group by bowler
)
select
    bowler,
    runs_conceded,
    legal_balls,
    round(6.0 * runs_conceded / nullif(legal_balls, 0), 2) as economy_rate
from bowler_stats
where legal_balls >= 300
order by economy_rate, bowler
limit 20;

-- 6. deliveries where the batter scored four or six runs off the bat.
-- these columns are scoring values, not a dedicated boundary flag in the source data.
select
    batsman,
    count(*) filter (where batsman_runs = 4) as four_run_batter_deliveries,
    count(*) filter (where batsman_runs = 6) as six_run_batter_deliveries,
    sum(batsman_runs) as total_runs_off_bat
from public.deliveries
where inning <= 2
group by batsman
order by six_run_batter_deliveries desc, four_run_batter_deliveries desc
limit 20;

-- 7. players with at least three player-of-the-match awards.
select
    player_of_match,
    count(*) as awards,
    min(date) as first_award_date,
    max(date) as latest_award_date,
    (max(date) - min(date)) as days_between_first_and_latest_award
from public.matches
where player_of_match is not null
group by player_of_match
having count(*) >= 3
order by awards desc, player_of_match;

-- 8. batter runs and distinct batter counts by country.
-- unmapped names stay visible instead of being silently dropped.
select
    coalesce(pc.country, 'unmapped') as country,
    sum(d.batsman_runs) as runs_off_bat,
    count(distinct d.batsman) as batter_count,
    count(*) as delivery_rows
from public.deliveries d
left join public.player_country pc
    on lower(btrim(pc.player_name)) = lower(btrim(d.batsman))
where d.inning <= 2
group by coalesce(pc.country, 'unmapped')
order by runs_off_bat desc;

-- 9. batter-versus-bowler matchups with at least 12 balls faced.
select
    d.batsman,
    d.bowler,
    sum(d.batsman_runs) as runs_off_bat,
    count(*) filter (where d.wide_runs = 0) as balls_faced,
    round(
        100.0 * sum(d.batsman_runs)
        / nullif(count(*) filter (where d.wide_runs = 0), 0),
        2
    ) as strike_rate,
    count(*) filter (
        where d.player_dismissed = d.batsman
          and d.dismissal_kind in ('bowled', 'caught', 'caught and bowled', 'lbw', 'stumped', 'hit wicket')
    ) as bowler_credited_dismissals
from public.deliveries d
where d.inning <= 2
group by d.batsman, d.bowler
having count(*) filter (where d.wide_runs = 0) >= 12
order by bowler_credited_dismissals desc, strike_rate desc
limit 50;

-- 10. batting consistency by player innings, requiring at least ten innings.
-- lower standard deviation indicates less variation; it does not automatically mean better performance.
with innings_scores as (
    select
        d.batsman,
        d.match_id,
        d.inning,
        sum(d.batsman_runs) as innings_runs
    from public.deliveries d
    where d.inning <= 2
    group by d.batsman, d.match_id, d.inning
),
player_consistency as (
    select
        batsman,
        count(*) as innings,
        avg(innings_runs) as average_runs,
        percentile_cont(0.5) within group (order by innings_runs) as median_runs,
        stddev_pop(innings_runs) as run_standard_deviation
    from innings_scores
    group by batsman
    having count(*) >= 10
)
select
    batsman,
    innings,
    round(average_runs::numeric, 2) as average_runs,
    round(median_runs::numeric, 2) as median_runs,
    round(run_standard_deviation::numeric, 2) as run_standard_deviation,
    round(100.0 * run_standard_deviation / nullif(average_runs, 0), 2) as coefficient_of_variation_pct
from player_consistency
order by average_runs desc;
