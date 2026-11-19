-- Pohlaví pro výběr tabulky silových standardů.
--
-- Strength Level publikuje zvlášť mužské a ženské tabulky, takže bez
-- tohohle sloupce by ženy dostávaly mužské prahy.
--
-- null = zatím nevyplněno; aplikace v takovém případě použije mužskou
-- tabulku a onboarding se zeptá znovu.

alter table public.users
  add column if not exists sex text check (sex in ('male', 'female'));
