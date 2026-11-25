-- Apply only during coordinated stabilization release, after fresh backup and logout of affected garage.
-- Preview verified against version 0 and original hash. Abort on any intervening change.
begin;
do $$
declare n integer;
begin
update public.garage_data
set data=(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(data::text,'Ã©','é'),'Ã¯','ï'),'â³','⏳'),'Å“','œ'),'Ã¨','è'),'â€™','’'),'Ã‰','É'),'ðŸ“Œ','📌'),'Â ',' '),'Ã ','à'),'â†ª','↪'),'âŒ','❌'),'âœ”','✔'),'âœ¨','✨'),'âž¡','➡'),'ðŸŒŸ','🌟'),'ðŸš©','🚩'),'ðŸŽ¯','🎯'))::jsonb, version=version+1,updated_at=now()
where garage_id='c010dd41-232a-426a-a83b-1783cc771992'
and user_id='acf0bc84-2001-49e1-851b-f4bc74cf2876'
and version=0 and md5(data::text)='71413fb9eb347ba90b6314b91c146d70'
and md5(((replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(replace(data::text,'Ã©','é'),'Ã¯','ï'),'â³','⏳'),'Å“','œ'),'Ã¨','è'),'â€™','’'),'Ã‰','É'),'ðŸ“Œ','📌'),'Â ',' '),'Ã ','à'),'â†ª','↪'),'âŒ','❌'),'âœ”','✔'),'âœ¨','✨'),'âž¡','➡'),'ðŸŒŸ','🌟'),'ðŸš©','🚩'),'ðŸŽ¯','🎯'))::jsonb)::text)='e0cc309df9563d0a570b01147a7fe29b';
get diagnostics n=row_count;
if n<>1 then raise exception 'Encoding repair aborted: snapshot changed or row not unique'; end if;
end $$;
commit;
