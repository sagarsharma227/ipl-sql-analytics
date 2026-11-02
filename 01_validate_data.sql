-- run these checks after importing the three csv files.
-- queries that find problems return rows; an empty result is expected for those checks.

-- 1. row counts for the three source tables.
select 'matches' as table_name, count(*) as row_count
from public.matches
union all
select 'deliveries', count(*)
from public.deliveries
union all
select 'player_country', count(*)
from public.player_country
order by table_name;

-- 2. match ids with duplicate records. expected: no rows.
select match_id, count(*) as row_count
from public.matches
group by match_id
having count(*) > 1;

-- 3. delivery rows whose match id is missing from the match table. expected: no rows.
select d.match_id, count(*) as delivery_rows
from public.deliveries d
left join public.matches m
    on m.match_id = d.match_id
where m.match_id is null
group by d.match_id
order by d.match_id;

-- 4. matches that have more than one batting team recorded in the first innings.
-- expected: no rows for this dataset.
select match_id, count(distinct batting_team) as first_innings_teams
from public.deliveries
where inning = 1
group by match_id
having count(distinct batting_team) <> 1
order by match_id;

-- 5. null result fields and special match outcomes.
select
    count(*) as total_matches,
    count(*) filter (where winner is null) as matches_without_recorded_winner,
    count(*) filter (where outcome = 'tie') as tied_matches,
    count(*) filter (where outcome = 'no result') as no_result_matches,
    count(*) filter (where method is not null) as matches_with_special_method
from public.matches;

-- 6. count deliveries in innings beyond the first two.
-- these are excluded from standard innings analyses in this project.
select inning, count(*) as delivery_rows
from public.deliveries
where inning > 2
group by inning
order by inning;

-- 7. player-country mapping coverage among distinct batter names.
select
    count(distinct lower(btrim(d.batsman))) as distinct_batters,
    count(distinct lower(btrim(d.batsman))) filter (where pc.player_name is not null) as mapped_batters,
    count(distinct lower(btrim(d.batsman))) filter (where pc.player_name is null) as unmapped_batters,
    round(
        100.0 * count(distinct lower(btrim(d.batsman))) filter (where pc.player_name is not null)
        / nullif(count(distinct lower(btrim(d.batsman))), 0),
        2
    ) as mapping_coverage_pct
from public.deliveries d
left join public.player_country pc
    on lower(btrim(pc.player_name)) = lower(btrim(d.batsman));

-- 8. list batter names that do not match the player-country lookup after trimming and lowercasing.
select distinct d.batsman as unmapped_batter
from public.deliveries d
left join public.player_country pc
    on lower(btrim(pc.player_name)) = lower(btrim(d.batsman))
where pc.player_name is null
order by unmapped_batter;

-- 9. lookup records that do not appear as a batter or bowler in the delivery data.
select pc.player_name, pc.country
from public.player_country pc
where not exists (
    select 1
    from public.deliveries d
    where lower(btrim(d.batsman)) = lower(btrim(pc.player_name))
       or lower(btrim(d.bowler)) = lower(btrim(pc.player_name))
)
order by pc.player_name;

-- 10. compare team names recorded in matches with names recorded in deliveries.
with match_teams as (
    select team1 as team from public.matches where team1 is not null
    union
    select team2 from public.matches where team2 is not null
),
delivery_teams as (
    select batting_team as team from public.deliveries where batting_team is not null
    union
    select bowling_team from public.deliveries where bowling_team is not null
)
select 'in both tables' as status, team
from (
    select team from match_teams
    intersect
    select team from delivery_teams
) matched_teams
union all
select 'only in matches', team
from (
    select team from match_teams
    except
    select team from delivery_teams
) match_only
union all
select 'only in deliveries', team
from (
    select team from delivery_teams
    except
    select team from match_teams
) delivery_only
order by status, team;

-- 11. repeated displayed delivery keys. duplicates are reported, not deleted, because the source contains them.
select
    match_id,
    inning,
    "over",
    ball,
    count(*) as rows_with_same_displayed_key
from public.deliveries
group by match_id, inning, "over", ball
having count(*) > 1
order by rows_with_same_displayed_key desc, match_id, inning, "over", ball
limit 50;
