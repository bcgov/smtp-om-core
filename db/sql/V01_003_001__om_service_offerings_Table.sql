--drop table OM.OM_SERVICE_OFFERINGS;

--**************************************************************************************
--* SQL script to create OM.OM_SERVICE_OFFERINGS table, primary key, foreign key(s) and indexes.  
--* This table is built based on Oracle E-Business Suite table MTL_SYSTEM_ITEMS_B
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-02              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_SERVICE_OFFERINGS
(
  SEOF_RK  NUMBER(9) not null,
  DISPLAY_NAME         VARCHAR2 (40), 
  UNIT_OF_MEASURE      VARCHAR2 (3),
  SAW_OFFERING_ID      NUMBER(9) not null,
  CRE_USER             VARCHAR2(30) not null,
  CRE_SRC              VARCHAR2(100) not null,
  CRE_TMSTMP           TIMESTAMP(6) not null,
  UPD_USER             VARCHAR2(30) not null,
  UPD_SRC              VARCHAR2(100) not null,
  UPD_TMSTMP           TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_SERVICE_OFFERINGS is 'This table holds the definitions for the Service Catalog in SAW. This table is similar to MTL_SYSTEM_ITEMS_B table in CAS.';
comment on column OM.OM_SERVICE_OFFERINGS.SEOF_RK is 'A unique system generated identifier for OM_SERVICE_OFFERINGS. This column is similar to MTL_SYSTEM_ITEMS_B.inventory_item_id in CAS.'; 
comment on column OM.OM_SERVICE_OFFERINGS.DISPLAY_NAME is 'This column is similar to MTL_SYSTEM_ITEMS_B.segment1 in CAS.';
comment on column OM.OM_SERVICE_OFFERINGS.UNIT_OF_MEASURE is '3-character unit that is used as measure of the service offering. This column is similar to MTL_SYSTEM_ITEMS_B.primary_uom_code in CAS.';
comment on column OM.OM_SERVICE_OFFERINGS.SAW_OFFERING_ID is 'Offering ID from SAW';
comment on column OM.OM_SERVICE_OFFERINGS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_SERVICE_OFFERINGS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_SERVICE_OFFERINGS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_SERVICE_OFFERINGS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_SERVICE_OFFERINGS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_SERVICE_OFFERINGS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
alter table OM.OM_SERVICE_OFFERINGS
  add constraint SEOF_PK primary key (SEOF_RK) 
  using index tablespace OMIDX;
  
/*prompt
prompt Creating sequence SEOF_RK_SEQ
prompt =============================
prompt*/
create sequence OM.SEOF_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger SEOF_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.SEOF_BR_I_TR
 BEFORE INSERT
 ON OM.OM_SERVICE_OFFERINGS
 FOR EACH ROW
begin
  if :new.SEOF_RK is null
  then
    select SEOF_RK_seq.nextval
    into  :new.SEOF_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger SEOF_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.SEOF_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_SERVICE_OFFERINGS
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
--create  PUBLIC synonym OM_SERVICE_OFFERINGS FOR OM.OM_SERVICE_OFFERINGS;
create or replace  public synonym OM_SERVICE_OFFERINGS FOR OM.OM_SERVICE_OFFERINGS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_SERVICE_OFFERINGS TO OMSERVICE WITH GRANT OPTION;


