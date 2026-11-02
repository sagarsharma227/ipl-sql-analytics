# metric definitions

## scope

- standard batting and bowling queries include innings 1 and 2 only.
- innings greater than 2 are excluded from standard performance metrics as they may represent super overs or other extra innings.
- season is kept as text because the source contains labels such as `2007/08`, `2009/10` and `2020/21`.
- team names are used as they appear in the source. historical franchise name changes are not consolidated in these scripts.

## batting

- runs off the bat: `sum(batsman_runs)`.
- balls faced: count deliveries where `wide_runs = 0`. no-balls count as balls faced in this definition; wides do not.
- strike rate: runs off the bat divided by balls faced, multiplied by 100.
- four-run and six-run batter deliveries: rows where `batsman_runs` is 4 or 6. the source does not provide a separate boundary flag, so these labels describe the recorded batter-run value.

## bowling

- legal balls: count deliveries where both `wide_runs = 0` and `noball_runs = 0`.
- runs conceded: total delivery runs excluding byes, leg-byes and penalty runs.
- economy rate: runs conceded divided by legal balls, multiplied by 6.
- bowler-credited wickets: dismissals recorded as bowled, caught, caught and bowled, lbw, stumped or hit wicket. run outs and other non-bowler-credited dismissals are excluded.

## match results

- team win percentage: wins divided by matches with a recorded winner for that team; tied and no-result matches do not enter the denominator.
- toss-winning team win percentage: matches in which the toss winner also won, divided by matches with both a recorded toss winner and match winner.
- batting-first win percentage by score band: batting-first wins divided by decisive matches with a recorded first-innings total in that band.
- closest finishes by runs and wickets are ranked separately because the margin units are not comparable.

## player-country mapping

- names are matched after `lower(btrim(name))` normalization.
- unmatched player names are labelled `unmapped`, not dropped.
- this mapping does not merge aliases or historical name variants unless an explicit mapping is added.

## performance testing

- index improvements must be measured with `explain (analyze, buffers)` on the actual database.
- runtime can vary due to caching, database settings and concurrent activity. do not report an improvement unless the benchmark is reproducible.
