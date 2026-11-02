-- advanced analysis using window functions, ntile, rollup and consecutive-result grouping.

-- 1. phase-wise batting performance by team and season.
-- source overs start at zero, so over values 0-5 are the powerplay, 6-14 are middle overs, and 15+ are death overs.
select
    m.season,
    d.batting_team,
    case
        when d."over" <= 5 then 'powerplay'
        when d."over" <= 14 then 'middle overs'
        else 'death overs'
    end as innings_phase,
    sum(d.batsman_runs + d.extras) as total_runs,
    count(*) filter (where d.wide_runs = 0 and d.noball_runs = 0) as legal_balls,
    round(
        6.0 * sum(d.batsman_runs + d.extras)
        / nullif(count(*) filter (where d.wide_runs = 0 and d.noball_runs = 0), 0),
        2
    ) as runs_per_six_legal_balls,
    count(*) filter (where d.batsman_runs = 4) as four_run_batter_deliveries,
    count(*) filter (where d.batsman_runs = 6) as six_run_batter_deliveries
from public.deliveries d
join public.matches m
    on m.match_id = d.match_id
where d.inning <= 2
group by m.season, d.batting_team, innings_phase
order by min(m.date), d.batting_team, min(d."over");

-- 2. each batter's share of team runs scored off the bat by season.
-- ntile creates four relative groups; ties can be split across quartiles.
with season_calendar as (
    select season, min(date) as season_start
    from public.matches
    group by season
),
batter_season_runs as (
    select
        m.season,
        d.batting_team,
        d.batsman,
        sum(d.batsman_runs) as batter_runs
    from public.deliveries d
    join public.matches m
        on m.match_id = d.match_id
    where d.inning <= 2
    group by m.season, d.batting_team, d.batsman
),
contribution as (
    select
        *,
        sum(batter_runs) over (partition by season, batting_team) as team_runs_off_bat,
        round(
            100.0 * batter_runs
            / nullif(sum(batter_runs) over (partition by season, batting_team), 0),
            2
        ) as run_share_pct,
        ntile(4) over (partition by season order by batter_runs desc) as season_run_quartile
    from batter_season_runs
)
select
    c.season,
    c.batting_team,
    c.batsman,
    c.batter_runs,
    c.team_runs_off_bat,
    c.run_share_pct,
    c.season_run_quartile
from contribution c
join season_calendar sc
    on sc.season = c.season
order by sc.season_start, c.season, c.batting_team, c.batter_runs desc;

-- 3. longest runs of consecutive wins by team.
-- ties and no-results count as non-wins and therefore break a streak.
with team_results as (
    select
        match_id,
        date,
        team1 as team,
        case when winner = team1 then 'win' else 'not win' end as result
    from public.matches
    union all
    select
        match_id,
        date,
        team2 as team,
        case when winner = team2 then 'win' else 'not win' end as result
    from public.matches
),
streak_groups as (
    select
        *,
        sum(case when result <> 'win' then 1 else 0 end) over (
            partition by team
            order by date, match_id
            rows between unbounded preceding and current row
        ) as streak_group
    from team_results
)
select
    team,
    count(*) as consecutive_wins,
    min(date) as streak_start,
    max(date) as streak_end
from streak_groups
where result = 'win'
group by team, streak_group
having count(*) >= 3
order by consecutive_wins desc, streak_start;

-- 4. season and innings run totals with subtotals and an overall total using rollup.
select
    case when grouping(m.season) = 1 then 'all seasons' else m.season end as season_group,
    case when grouping(d.inning) = 1 then 'all innings' else d.inning::text end as innings_group,
    sum(d.batsman_runs + d.extras) as total_runs,
    count(distinct d.match_id) as matches
from public.deliveries d
join public.matches m
    on m.match_id = d.match_id
where d.inning <= 2
group by rollup (m.season, d.inning)
order by grouping(m.season), min(m.date) nulls last, grouping(d.inning), d.inning;

-- 5. identify players who have scored at least 50 runs in innings against three or more teams.
with batter_team_innings as (
    select
        d.batsman,
        d.bowling_team as opponent,
        d.match_id,
        sum(d.batsman_runs) as innings_runs
    from public.deliveries d
    where d.inning <= 2
    group by d.batsman, d.bowling_team, d.match_id
),
eligible_players as (
    select distinct bti.batsman
    from batter_team_innings bti
    where bti.innings_runs >= 50
      and exists (
          select 1
          from batter_team_innings other_opponents
          where other_opponents.batsman = bti.batsman
            and other_opponents.innings_runs >= 50
            and other_opponents.opponent <> bti.opponent
      )
)
select
    bti.batsman,
    count(distinct bti.opponent) filter (where bti.innings_runs >= 50) as opponents_against_whom_they_scored_50_plus,
    count(*) filter (where bti.innings_runs >= 50) as 50_plus_innings
from batter_team_innings bti
join eligible_players ep
    on ep.batsman = bti.batsman
where bti.innings_runs >= 50
group by bti.batsman
having count(distinct bti.opponent) >= 3
order by opponents_against_whom_they_scored_50_plus desc, 50_plus_innings desc;
