# summaries

update marc_subfield_structure set kohafield=null where kohafield like "summaries.%";

# Item type field changes

alter table items drop foreign key items_fk_4;    #key name changes some--references itemtypes.
alter table items drop key itemtype; 
alter table items drop foreign key items_ibfk_4;
alter table items change itemtype itype varchar(10) default null;
alter table deleteditems change itemtype itype varchar(10) default null;
update marc_subfield_structure set kohafield='items.itype' where kohafield='items.itemtype';
insert into systempreferences (variable,value,explanation,type) values ("item-level_itypes",1,"If On, enabled Item-level Itemtype / Issuing Rules","YesNo");
alter table itemtypes drop column replacement_price;

# authorised values table

alter table authorised_values change opaclib lib_opac varchar(80) default NULL;

# Catstat/Biblios/GetIt

alter table items drop column catstat;
alter table deleteditems drop column catstat;
alter table biblioitems drop column on_order_count;
alter table biblioitems drop column in_process_count;
alter table deletedbiblioitems drop column on_order_count;
alter table deletedbiblioitems drop column in_process_count;
delete from authorised_values where category="catstat";
delete from systempreferences where variable="GetItAcquisitions";
delete from systempreferences where variable= "BibliosCataloging";
delete from marc_subfield_structure where tagfield="942" and tagsubfield="t";
delete from marc_subfield_structure where tagfield="942" and tagsubfield="u";
delete from marc_subfield_structure where tagfield="952" and tagsubfield="k";

# Un-remove link

update marc_subfield_structure set kohafield="items.coded_location_qualifier" where tagfield="952" and tagsubfield="f";

# System preferences

update systempreferences set options='itemtypes|ccode' where variable = 'AdvancedSearchTypes';


