
ALTER TABLE items ADD KEY cn_sort (cn_sort);
alter table sessions change a_session a_session longtext NOT NULL;

update systempreferences set value=0 where type='yesno' and value in ('off','no');
update systempreferences set value=1 where type='yesno' and value in ('on','yes');

