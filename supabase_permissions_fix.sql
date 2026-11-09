-- 공동 현황판 권한과 집계 함수 보완
-- Supabase SQL Editor에서 전체 실행

create table if not exists public.teacher_type_results (
  id bigint generated always as identity primary key,
  best_type text not null check (best_type in ('cat','dog','rabbit','octopus','turtle')),
  school_level text not null check (school_level in ('유치원','초등학교','특수/기타')),
  scores jsonb not null,
  created_at timestamptz not null default now()
);

alter table public.teacher_type_results enable row level security;

drop policy if exists "anonymous can submit teacher type result" on public.teacher_type_results;
create policy "anonymous can submit teacher type result"
on public.teacher_type_results
for insert to anon
with check (
  best_type in ('cat','dog','rabbit','octopus','turtle')
  and school_level in ('유치원','초등학교','특수/기타')
);

grant usage on schema public to anon, authenticated;
grant insert on table public.teacher_type_results to anon, authenticated;

create or replace function public.get_teacher_type_stats()
returns jsonb
language sql
security definer
set search_path = public
as $$
  with type_totals as (
    select best_type, count(*)::int as n
    from public.teacher_type_results
    group by best_type
  ),
  school_totals as (
    select school_level, best_type, count(*)::int as n
    from public.teacher_type_results
    group by school_level, best_type
  ),
  school_json as (
    select school_level,
           jsonb_object_agg(best_type, n) as type_counts,
           sum(n)::int as total_count
    from school_totals
    group by school_level
  )
  select jsonb_build_object(
    'type_counts',
      coalesce((select jsonb_object_agg(best_type,n) from type_totals),'{}'::jsonb),
    'school_counts',
      coalesce((
        select jsonb_object_agg(
          school_level,
          type_counts || jsonb_build_object('_total', total_count)
        ) from school_json
      ),'{}'::jsonb)
  );
$$;

grant execute on function public.get_teacher_type_stats() to anon, authenticated;
