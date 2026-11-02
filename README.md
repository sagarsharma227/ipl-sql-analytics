# IPL Performance and Player Nationality Analysis (2008–2025)

A PostgreSQL portfolio project that explores Indian Premier League match results, ball-by-ball performance, player nationality, and venue trends through the 2025 season.

## Project overview

This project uses three cleaned IPL datasets to answer practical cricket-analysis questions with SQL. The analysis covers team performance, player statistics, match and venue patterns, advanced window-function analysis, and basic query-performance tuning.

## Key questions

- Which teams have the most wins and the best win percentage by season?
- Does the toss decision relate to match outcomes?
- Who are the leading batters and bowlers under defined eligibility rules?
- How do batting results differ by innings phase and venue?
- Which batter-bowler matchups stand out?
- How do first-innings score ranges relate to the final result?

## Tools and skills demonstrated

- PostgreSQL
- Data validation and quality checks
- Joins, CTEs, subqueries, and conditional aggregation
- Window functions, including `RANK`, `DENSE_RANK`, `ROW_NUMBER`, `LAG`, and `NTILE`
- `CASE`, `COALESCE`, `NULLIF`, date functions, and statistical aggregates
- Indexes, `ANALYZE`, and `EXPLAIN (ANALYZE, BUFFERS)`
- A reusable SQL function for batter summaries

## Files

| File | Purpose |
| --- | --- |
| `00_create_tables.sql` | Creates the PostgreSQL tables for matches, deliveries, and player-country data. |
| `01_validate_data.sql` | Checks row counts, keys, nulls, and data coverage after import. |
| `02_team_analysis.sql` | Team wins, win percentages, toss outcomes, and team-level comparisons. |
| `03_player_analysis.sql` | Batting, bowling, nationality, and player-performance analysis. |
| `04_match_venue_analysis.sql` | Venue patterns, innings scores, and match-result analysis. |
| `05_advanced_analytics.sql` | Advanced SQL patterns, including CTEs and window functions. |
| `06_performance_optimization.sql` | Index and query-plan examples. |
| `07_routines_demo.sql` | Reusable SQL function example. |
| `metric_definitions.md` | Definitions, exclusions, and calculation rules for the reported metrics. |
| `matches_cleaned.csv` | Match-level IPL data. |
| `deliveries_cleaned.csv` | Ball-by-ball IPL delivery data. |
| `player_country_cleaned.csv` | Player nationality lookup data. |

## Dataset relationship

```text
matches_cleaned
    match_id
       |
       | one-to-many
       v
deliveries_cleaned

player_country_cleaned
    player_name -> batsman / bowler names after trimming and lowercasing
```

## Setup

1. Create an empty PostgreSQL database.
2. Run `00_create_tables.sql`.
3. Import `matches_cleaned.csv`, `deliveries_cleaned.csv`, and `player_country_cleaned.csv` into the matching tables.
4. Run `01_validate_data.sql` and review the results.
5. Run the analysis scripts from `02_team_analysis.sql` through `05_advanced_analytics.sql`.
6. Run `06_performance_optimization.sql` only after the data is imported.

## Notes and limitations

- Standard batting and bowling metrics use innings 1 and 2; extra innings such as super overs are excluded.
- Historical franchise names are kept as recorded in the source data.
- Player-country matching uses cleaned names and may not resolve every alias.
- This is retrospective analysis, not a predictive model or a claim of causation.
- Before publishing the CSVs in a public repository, confirm that the original data source permits redistribution. The SQL and documentation can be published independently.

## Author

Sagar Sharma
