-- match and venue analysis using date functions, case expressions and ranked results.

-- 1. venues with the highest average first-innings score, with at least 20 regular-method first innings.
-- matches with a recorded special method (for example, d/l) are excluded for comparability.
with first_innings as (
    select
        match_id,
        batting_team as first_batting_team,
        sum(batsman_runs + extras) as first_innings_runs
    from public.deliveries
    where inning = 1
    group by match_id, batting_team
)
select
    m.venue,
    count(*) as recorded_first_innings,
    round(avg(f.first_innings_runs)::numeric, 2) as average_first_innings_score,
    min(f.first_innings_runs) as lowest_first_innings_score,
    max(f.first_innings_runs) as highest_first_innings_score
from public.matches m
join first_innings f
    on f.match_id = m.match_id
where m.venue is not null
  and m.method is null
group by m.venue
having count(*) >= 20
order by average_first_innings_score desc;

-- 2. first-innings score bands and the percentage of decisive matches won by the team batting first.
-- matches with a recorded special method are excluded from this comparison.
with first_innings as (
    select
        match_id,
        batting_team as first_batting_team,
        sum(batsman_runs + extras) as first_innings_runs
    from public.deliveries
    where inning = 1
    group by match_id, batting_team
),
decided_matches as (
    select
        m.match_id,
        m.winner,
        f.first_batting_team,
        f.first_innings_runs,
        case
            when f.first_innings_runs >= 200 then '200+'
            when f.first_innings_runs >= 180 then '180-199'
            when f.first_innings_runs >= 160 then '160-179'
            when f.first_innings_runs >= 140 then '140-159'
            else 'below 140'
        end as score_band
    from public.matches m
    join first_innings f
        on f.match_id = m.match_id
    where m.winner is not null
      and m.method is null
)
select
    score_band,
    count(*) as decisive_matches,
    count(*) filter (where winner = first_batting_team) as batting_first_wins,
    count(*) filter (where winner <> first_batting_team) as chasing_wins,
    round(
        100.0 * count(*) filter (where winner = first_batting_team)
        / nullif(count(*), 0),
        2
    ) as batting_first_win_pct
from decided_matches
group by score_band
order by min(first_innings_runs) desc;

-- 3. ten closest wins by runs and ten closest wins by wickets.
with margins as (
    select
        match_id,
        date,
        team1,
        team2,
        winner,
        'runs' as margin_type,
        winner_runs as margin
    from public.matches
    where winner is not null
      and winner_runs is not null
    union all
    select
        match_id,
        date,
        team1,
        team2,
        winner,
        'wickets' as margin_type,
        winner_wickets as margin
    from public.matches
    where winner is not null
      and winner_wickets is not null
),
ranked_margins as (
    select
        *,
        row_number() over (
            partition by margin_type
            order by margin, date, match_id
        ) as margin_rank
    from margins
)
select date, team1, team2, winner, margin_type, margin, margin_rank
from ranked_margins
where margin_rank <= 10
order by margin_type, margin, date;

-- 4. match counts by calendar month using date_trunc, to_char and extract.
select
    date_trunc('month', date)::date as month_start,
    to_char(date, 'yyyy-mm') as calendar_month,
    extract(year from date)::integer as calendar_year,
    extract(month from date)::integer as month_number,
    count(*) as matches,
    count(*) filter (where winner is not null) as matches_with_winner,
    count(*) filter (where outcome = 'no result') as no_result_matches
from public.matches
group by date_trunc('month', date)::date, to_char(date, 'yyyy-mm'),
         extract(year from date), extract(month from date)
order by month_start;

-- 5. result and method summary, preserving missing values as explicit labels.
select
    coalesce(outcome, 'regular recorded result') as outcome_group,
    coalesce(method, 'no special method recorded') as result_method,
    count(*) as matches,
    count(*) filter (where winner is null) as matches_without_recorded_winner
from public.matches
group by coalesce(outcome, 'regular recorded result'),
         coalesce(method, 'no special method recorded')
order by matches desc;
