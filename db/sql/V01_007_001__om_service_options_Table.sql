--drop table OM.OM_SERVICE_OPTIONS;
--drop index OM.SEOP_SEOF_RK_FK_IX;

--**************************************************************************************
--* SQL script to create OM.OM_SERVICE_OPTIONS table, primary key, foreign key(s) and indexes. 
--* This table is built based on Oracle E-Business Suite table INV.MTL_PARAMETERS
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-07              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_SERVICE_OPTIONS
(
  SEOP_RK                 NUMBER(9) not null,
  SEOF_RK                 NUMBER(9) not null,
  SERVICE_OPTION_NAME     VARCHAR2(240) not null,
  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_SERVICE_OPTIONS is 'Represents the user options that are configured in the SAW service catalogue. This table is similar to INV.MTL_PARAMETERS table in Oracle E-Business Suite. In EBS INV.MTL_PARAMETERS  maintains a set of default options like general ledger accounts; locator, lot, and serial controls; inter-organization options; costing method; etc. for each organization defined in Oracle Inventory.';
comment on column OM.OM_SERVICE_OPTIONS.SEOP_RK is 'A unique system generated identifier for OM_SERVICE_OPTIONS.'; 
comment on column OM.OM_SERVICE_OPTIONS.SEOF_RK is 'The foreign key pointing at OM_SERVICE_OFFERINGS. This column was previously MTL_SYSTEM_ITEMS_B.inventory_item_id in Oracle E-Business suite.';
comment on column OM.OM_SERVICE_OPTIONS.SERVICE_OPTION_NAME is 'This column stores the name of the user options defined in the service offering within SAW. It is sourced from Offering.UserOption.Name in SAW.';

comment on column OM.OM_SERVICE_OPTIONS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_SERVICE_OPTIONS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_SERVICE_OPTIONS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_SERVICE_OPTIONS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_SERVICE_OPTIONS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_SERVICE_OPTIONS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_SERVICE_OPTIONS
  add constraint SEOP_PK primary key (SEOP_RK) 
  using index tablespace OMIDX;
--Foregin key  
alter table OM.OM_SERVICE_OPTIONS
  add constraint SEOP_SEOF_RK_FK foreign key (SEOF_RK)
  references OM.OM_SERVICE_OFFERINGS (SEOF_RK);
create index OM.SEOP_SEOF_RK_FK_IX on OM.OM_SERVICE_OPTIONS (SEOF_RK) 
tablespace OMIDX;  
  
/*prompt
prompt Creating sequence SEOP_RK_SEQ
prompt =============================
prompt*/
create sequence OM.SEOP_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger SEOP_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.SEOP_BR_I_TR
 BEFORE INSERT
 ON OM.OM_SERVICE_OPTIONS
 FOR EACH ROW
begin
  if :new.SEOP_RK is null
  then
    select SEOP_RK_seq.nextval
    into  :new.SEOP_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger SEOP_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.SEOP_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_SERVICE_OPTIONS
 FOR EACH ROW
BEGIN
  IF inserting
  THEN
    :new.cre_user := USER;
    IF :new.cre_src IS NULL
    THEN
      :new.cre_src := pkg_audit.fnc_get_transaction_source(:new.upd_src,:old.upd_src);
    END IF;
    :new.cre_tmstmp := current_timestamp;
    :new.upd_user   := :new.cre_user;
    :new.upd_src    := :new.cre_src;
    :new.upd_tmstmp := :new.cre_tmstmp;
  ELSIF updating
  THEN
    :new.cre_user   := :old.cre_user;
    :new.cre_src    := :old.cre_src;
    :new.cre_tmstmp := :old.cre_tmstmp;
    :new.upd_user   := USER;
    :new.upd_tmstmp := current_timestamp;

    --If new and old have the same value, and the columns was not
    --explicitly updated then overide with the value from the function
    IF (:new.upd_src = :old.upd_src AND NOT updating('upd_src'))
       OR :new.upd_src IS NULL
    THEN
      :new.upd_src := pkg_audit.fnc_get_transaction_source(:new.upd_src,:old.upd_src);
    END IF;

  END IF;
END;
/
create or replace public synonym OM_SERVICE_OPTIONS FOR OM.OM_SERVICE_OPTIONS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_SERVICE_OPTIONS TO OMSERVICE WITH GRANT OPTION;
