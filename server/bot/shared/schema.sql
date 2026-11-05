-- The Swarm's shared layer (database `swarm` on the Neon project `peeplet`).
-- Read and written by the bot server only (NEON_SWARM_URL). Nothing here may
-- identify a player: no uid, no session id, no transcript. Safe to re-run.
-- 384 = memory.embed.DIM (bge-small).
create extension if not exists vector;

-- Curated rows come from server/bot/knowledge/<lang>/<topic>.md through
-- tools/sync_swarm_knowledge.py; learned rows come from an accepted suggestion.
create table if not exists knowledge (
  id          bigserial primary key,
  lang        text        not null,
  topic       text        not null,
  text        text        not null,
  embedding   vector(384) not null,
  source      text        not null check (source in ('curated', 'learned')),
  active      boolean     not null default true,
  updated_at  timestamptz not null default now()
);
create index if not exists knowledge_lang_topic on knowledge (lang, topic, source);

-- Short notes appended to the prompt, and knobs (keys that start 'knob.').
create table if not exists style (
  key         text        not null,
  lang        text        not null,
  text        text        not null,
  active      boolean     not null default true,
  updated_at  timestamptz not null default now(),
  primary key (key, lang)
);

-- Numbers only: no text, no uid, no session id, day granularity.
create table if not exists turn_outcomes (
  day         date        not null,
  lang        text        not null,
  decision    integer     not null,
  features    real[]      not null,
  interrupted boolean     not null,
  gap_ms      integer     not null,
  call_s      integer     not null
);
create index if not exists turn_outcomes_day on turn_outcomes (day);

-- General, impersonal lessons distilled at call end; nothing goes live by itself.
create table if not exists suggestions (
  id          bigserial primary key,
  lang        text        not null,
  kind        text        not null check (kind in ('question', 'fix', 'fact', 'style')),
  text        text        not null,
  embedding   vector(384) not null,
  seen        integer     not null default 1,
  status      text        not null default 'pending' check (status in ('pending', 'accepted', 'rejected')),
  first_day   date        not null default current_date,
  last_day    date        not null default current_date
);
create index if not exists suggestions_status_seen on suggestions (status, seen desc);
