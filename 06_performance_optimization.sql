-- create these indexes after importing the csv files.
-- index usefulness depends on the query plan and the size of the table; benchmark before making performance claims.

create index if not exists idx_deliveries_match_inning
    on public.deliveries (match_id, inning);

create index if not exists idx_deliveries_batsman
    on public.deliveries (batsman);

create index if not exists idx_deliveries_bowler
    on public.deliveries (bowler);

create index if not exists idx_matches_season_date
    on public.matches (season, date);

-- refresh planner statistics after creating indexes.
analyze public.matches;
analyze public.deliveries;
analyze public.player_country;

-- compare the plan before and after creating an index.
-- run explain (analyze, buffers) separately before and after the index creation.
-- do not compare results from different cache states as if the index alone caused the difference.

-- example benchmark query:
-- explain (analyze, buffers)
-- select d.batsman, sum(d.batsman_runs) as runs
-- from public.deliveries d
-- where d.match_id = 335982
--   and d.inning <= 2
-- group by d.batsman
-- order by runs desc;
