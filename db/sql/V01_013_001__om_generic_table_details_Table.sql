/*drop table OM.OM_GENERIC_TABLE_DETAILS cascade constraints;
drop index OM.GTDE_SEOF_RK_FK_IX;
drop index OM.GTDE_ORDE_RK_FK_IX;
drop index OM.GTDE_GTDE_FK_IX;
*/
--**************************************************************************************
--* SQL script to create OM.OM_GENERIC_TABLE_DETAILS table, primary key, foreign key(s) and indexes. 
--* This table is built based on CAS table CAS_GENERIC_TABLE_DETAILS
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-04              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_GENERIC_TABLE_DETAILS
(
  GTDE_RK                 NUMBER(9) not null,
  CATEGORY            VARCHAR2(50 BYTE)         NOT NULL,
  KEY                 VARCHAR2(50 BYTE)         NOT NULL,
  DATA1               VARCHAR2(4000 BYTE),
  DATA2               VARCHAR2(100 BYTE),
  DATA3               VARCHAR2(100 BYTE),
  DATA4               VARCHAR2(100 BYTE),
  DATA5               VARCHAR2(100 BYTE),
  DATA6               VARCHAR2(100 BYTE),
  DATA7               VARCHAR2(100 BYTE),
  DATA8               VARCHAR2(100 BYTE),
  DATA9               VARCHAR2(100 BYTE),
  DATA10              VARCHAR2(100 BYTE),

  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_GENERIC_TABLE_DETAILS is 'Generic lookup table for parameters. This table is similar to CASCSI.CAS_GENERIC_TABLE_DETAILS table in CAS. ';
comment on column OM.OM_GENERIC_TABLE_DETAILS.GTDE_RK is 'A unique system generated identifier for OM_GENERIC_TABLE_DETAILS.'; 

comment on column OM.OM_GENERIC_TABLE_DETAILS.CATEGORY is 'key and Category uniquely identify the record. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.Category';
comment on column OM.OM_GENERIC_TABLE_DETAILS.KEY is 'key and Category uniquely identify the record. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.key';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA1 is 'Flex Field 1. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data1';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA2 is 'Flex Field 2. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data2';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA3 is 'Flex Field 3. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data3';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA4 is 'Flex Field 4. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data4';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA5 is 'Flex Field 5. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data5';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA6 is 'Flex Field 6. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data6';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA7 is 'Flex Field 7. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data7';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA8 is 'Flex Field 8. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data8';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA9 is 'Flex Field 9. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data9';
comment on column OM.OM_GENERIC_TABLE_DETAILS.DATA10 is 'Flex Field 10. This column was previously CASCSI.CAS_GENERIC_TABLE_DETAILS.data10';     
comment on column OM.OM_GENERIC_TABLE_DETAILS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_GENERIC_TABLE_DETAILS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_GENERIC_TABLE_DETAILS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the GTDErd was created.';          
comment on column OM.OM_GENERIC_TABLE_DETAILS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_GENERIC_TABLE_DETAILS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_GENERIC_TABLE_DETAILS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the GTDErd was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_GENERIC_TABLE_DETAILS
  add constraint GTDE_PK primary key (GTDE_RK) 
  using index tablespace OMIDX;

create unique index OM.GTDE_IDX_U1 on OM.OM_GENERIC_TABLE_DETAILS
(CATEGORY, KEY)
LOGGING
TABLESPACE OMIDX;
  
/*prompt
prompt Creating sequence GTDE_RK_SEQ
prompt =============================
prompt*/
create sequence OM.GTDE_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger GTDE_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.GTDE_BR_I_TR
 BEFORE INSERT
 ON OM.OM_GENERIC_TABLE_DETAILS
 FOR EACH ROW
begin
  if :new.GTDE_RK is null
  then
    select GTDE_RK_seq.nextval
    into  :new.GTDE_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger GTDE_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.GTDE_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_GENERIC_TABLE_DETAILS
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
create or replace public synonym OM_GENERIC_TABLE_DETAILS FOR OM.OM_GENERIC_TABLE_DETAILS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_GENERIC_TABLE_DETAILS TO OMSERVICE WITH GRANT OPTION;

