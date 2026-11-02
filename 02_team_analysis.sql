-- team-level analysis using aggregations, filters, case expressions, ctes and window functions.

-- 1. match volume and result coverage by season.
select
    season,
    min(date) as season_start,
    max(date) as season_end,
    count(*) as matches,
    count(*) filter (where winner is not null) as matches_with_winner,
    count(*) filter (where outcome = 'tie') as tied_matches,
    count(*) filter (where outcome = 'no result') as no_result_matches
from public.matches
group by season
order by min(date);

-- 2. wins and win percentage by team.
-- win percentage uses matches with a recorded winner as the denominator.
with team_matches as (
    select match_id, team1 as team, winner
    from public.matches
    union all
    select match_id, team2 as team, winner
    from public.matches
)
select
    team,
    count(*) as matches_played,
    count(*) filter (where winner = team) as wins,
    count(*) filter (where winner is not null) as decided_matches,
    round(
        100.0 * count(*) filter (where winner = team)
        / nullif(count(*) filter (where winner is not null), 0),
        2
    ) as win_pct_of_decided_matches
from team_matches
group by team
order by win_pct_of_decided_matches desc nulls last, wins desc;

-- 3. toss decision and the match-win rate of the toss-winning team.
select
    toss_decision,
    count(*) as matches_with_decided_result,
    count(*) filter (where toss_winner = winner) as toss_winner_match_wins,
    round(
        100.0 * count(*) filter (where toss_winner = winner)
        / nullif(count(*), 0),
        2
    ) as toss_winner_win_pct
from public.matches
where toss_winner is not null
  and winner is not null
group by toss_decision
order by toss_decision;

-- 4. wins while batting first versus chasing.
with first_batting as (
    select match_id, batting_team as first_batting_team
    from public.deliveries
    where inning = 1
    group by match_id, batting_team
),
decided_matches as (
    select
        m.match_id,
        case
            when m.winner = f.first_batting_team then 'batting first'
            else 'chasing'
        end as win_type
    from public.matches m
    join first_batting f
        on f.match_id = m.match_id
    where m.winner is not null
)
select
    win_type,
    count(*) as wins,
    round(100.0 * count(*) / nullif(sum(count(*)) over (), 0), 2) as share_of_decided_wins_pct
from decided_matches
group by win_type
order by wins desc;

-- 5. team win percentage by season and change from the team's previous recorded season.
with season_calendar as (
    select season, min(date) as season_start
    from public.matches
    group by season
),
team_matches as (
    select match_id, date, season, team1 as team, winner
    from public.matches
    union all
    select match_id, date, season, team2 as team, winner
    from public.matches
),
team_season as (
    select
        tm.team,
        tm.season,
        sc.season_start,
        count(*) as matches_played,
        count(*) filter (where tm.winner = tm.team) as wins,
        count(*) filter (where tm.winner is not null) as decided_matches
    from team_matches tm
    join season_calendar sc
        on sc.season = tm.season
    group by tm.team, tm.season, sc.season_start
),
season_rates as (
    select
        team,
        season,
        season_start,
        matches_played,
        wins,
        round(100.0 * wins / nullif(decided_matches, 0), 2) as win_pct
    from team_season
),
season_changes as (
    select
        *,
        lag(win_pct) over (partition by team order by season_start) as previous_recorded_season_win_pct
    from season_rates
)
select
    team,
    season,
    matches_played,
    wins,
    win_pct,
    previous_recorded_season_win_pct,
    round(win_pct - previous_recorded_season_win_pct, 2) as win_pct_point_change
from season_changes
order by season_start, team;

-- 6. match outcome counts by toss decision and winner identity.
select
    toss_decision,
    case
        when winner is null then 'no recorded winner'
        when toss_winner is null then 'no recorded toss winner'
        when toss_winner = winner then 'toss winner also won match'
        else 'toss winner lost match'
    end as result_group,
    count(*) as matches
from public.matches
group by toss_decision, result_group
order by toss_decision, result_group;
