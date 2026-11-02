
create table if not exists matches(
    match_id bigint primary key,
    season text not null,
    date date not null,
    venue text,
    city text,
    team1 text not null,
    team2 text not null,
    toss_winner text,
    toss_decision text check (toss_decision in ('bat', 'field')),
    winner text,
    winner_runs integer check (winner_runs is null or winner_runs >= 0),
    winner_wickets integer check (winner_wickets is null or winner_wickets >= 0),
    player_of_match text,
    eliminator text,
    method text,
    outcome text,
    neutral_venue boolean
);

select * from matches;

create table if not exists deliveries (
    match_id bigint not null references public.matches(match_id),
    inning integer not null check (inning >= 1),
    "over" integer not null check ("over" >= 0),
    ball integer not null check (ball >= 1),
    batting_team text not null,
    bowling_team text not null,
    batsman text not null,
    non_striker text not null,
    bowler text not null,
    batsman_runs integer not null default 0 check (batsman_runs >= 0),
    extras integer not null default 0 check (extras >= 0),
    wide_runs integer not null default 0 check (wide_runs >= 0),
    noball_runs integer not null default 0 check (noball_runs >= 0),
    bye_runs integer not null default 0 check (bye_runs >= 0),
    legbye_runs integer not null default 0 check (legbye_runs >= 0),
    penalty_runs integer not null default 0 check (penalty_runs >= 0),
    dismissal_kind text,
    player_dismissed text
);

select * from deliveries;

create table if not exists player_country(
    player_name text primary key,
    country text not null
);

select * from player_country;
