/*drop table OM.OM_FIN_PERIOD_SETS cascade constraints;
drop index OM.FPSE_SEOF_RK_FK_IX;
drop index OM.FPSE_ORDE_RK_FK_IX;
drop index OM.FPSE_FPSE_FK_IX;
*/
--**************************************************************************************
--* SQL script to create OM.OM_FIN_PERIOD_SETS table, primary key, foreign key(s) and indexes. 
--* This table is built based on CAS table CAS_GENERIC_TABLE_DETAILS
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-09              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_FIN_PERIOD_SETS
(
  FPSE_RK                 NUMBER(9) not null,
  PERIOD_SET_NAME         VARCHAR2 (15)  not null,

  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_FIN_PERIOD_SETS is 'Represents the GL Period Sets as stored in the Oracle E-Business Suite at CAS. OM_FIN_PERIOD_SETS stores the calendars defined at CAS using the Accounting Calendar form. Each row includes the name of the calendar period. There is a one-to-many relationship between a row in this table and rows in the OM_FIN_PERIODS table. This table has no foreign keys other than the standard audit columns. This table is similar to SQLGL.GL_PERIOD_SETS  table in Oracle E-Business suite. ';
comment on column OM.OM_FIN_PERIOD_SETS.FPSE_RK is 'A unique system generated identifier for OM_FIN_PERIOD_SETS.';  
comment on column OM.OM_FIN_PERIOD_SETS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_FIN_PERIOD_SETS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_FIN_PERIOD_SETS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the FPSErd was created.';          
comment on column OM.OM_FIN_PERIOD_SETS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_FIN_PERIOD_SETS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_FIN_PERIOD_SETS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the FPSErd was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_FIN_PERIOD_SETS
  add constraint FPSE_PK primary key (FPSE_RK) 
  using index tablespace OMIDX;

create unique index OM.FPSE_IDX_U1 on OM.OM_FIN_PERIOD_SETS
(PERIOD_SET_NAME)
LOGGING
TABLESPACE OMIDX;
 
/*prompt
prompt Creating sequence FPSE_RK_SEQ
prompt =============================
prompt*/
create sequence OM.FPSE_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger FPSE_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.FPSE_BR_I_TR
 BEFORE INSERT
 ON OM.OM_FIN_PERIOD_SETS
 FOR EACH ROW
begin
  if :new.FPSE_RK is null
  then
    select FPSE_RK_seq.nextval
    into  :new.FPSE_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger FPSE_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.FPSE_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_FIN_PERIOD_SETS
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
create or replace public synonym OM_FIN_PERIOD_SETS FOR OM.OM_FIN_PERIOD_SETS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_FIN_PERIOD_SETS TO OMSERVICE WITH GRANT OPTION;

