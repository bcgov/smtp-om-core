/*drop table OM.OM_FIN_PERIODS cascade constraints;
drop index OM.FIPE_FPSE_RK_FK_IX;

drop index OM.FIPE_FIPE_FK_IX;
*/
--**************************************************************************************
--* SQL script to create OM.OM_FIN_PERIODS table, primary key, foreign key(s), synonyms and indexes. 
--* This table is built based on CAS table CAS_GENERIC_TABLE_DETAILS
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-09              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_FIN_PERIODS
(
  FIPE_RK                 NUMBER(9)     not null,
  FPSE_RK                 NUMBER(9)     not null,
  PERIOD_NAME             VARCHAR2(15)  not null,
  PERIOD_YEAR             NUMBER (15)   not null,
  START_DATE              DATE          not null,
  END_DATE                DATE          not null,

  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_FIN_PERIODS is 'Represents the GL Periods as stored in the the Oracle E-Business Suite at CAS. OM_FIN_PERIODS stores information about the accounting periods defined in E-Business suite. Each row includes the start date and end date of the period, the fiscal year, and other information. There is a one-to-many relationship between a row in the OM_FIN_PERIODS_SETS table and rows in this table.';
comment on column OM.OM_FIN_PERIODS.FIPE_RK is 'A unique system generated identifier for OM_FIN_PERIODS.'; 
comment on column OM.OM_FIN_PERIODS.FPSE_RK is 'A foregin key pointing to OM.OM_FIN_PERIOD_SETS table';  
comment on column OM.OM_FIN_PERIODS.PERIOD_NAME is 'System generated accounting period name. This column is sourced from CAS DW.';
comment on column OM.OM_FIN_PERIODS.PERIOD_YEAR is 'Accounting period year. This column is sourced from CAS DW.';
comment on column OM.OM_FIN_PERIODS.START_DATE is 'Date on which accounting period begins. This column is sourced from CAS DW.'; 
comment on column OM.OM_FIN_PERIODS.END_DATE  is 'Date on which accounting period ends. This column is sourced from CAS DW.';
comment on column OM.OM_FIN_PERIODS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_FIN_PERIODS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_FIN_PERIODS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the FIPErd was created.';          
comment on column OM.OM_FIN_PERIODS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_FIN_PERIODS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_FIN_PERIODS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the FIPErd was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_FIN_PERIODS
  add constraint FIPE_PK primary key (FIPE_RK) 
  using index tablespace OMIDX;

/*create unique index OM.FIPE_IDX_U1 on OM.OM_FIN_PERIODS
(PERIOD_NAME )
LOGGING
TABLESPACE OMIDX;*/

--Foregin key  
alter table OM.OM_FIN_PERIODS
  add constraint FIPE_FPSE_RK_FK foreign key (FPSE_RK)
  references OM.OM_FIN_PERIOD_SETS (FPSE_RK);
create index OM.FIPE_FPSE_RK_FK_IX on OM.OM_FIN_PERIODS (FPSE_RK) 
tablespace OMIDX;  
 
/*prompt
prompt Creating sequence FIPE_RK_SEQ
prompt =============================
prompt*/
create sequence OM.FIPE_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger FIPE_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.FIPE_BR_I_TR
 BEFORE INSERT
 ON OM.OM_FIN_PERIODS
 FOR EACH ROW
begin
  if :new.FIPE_RK is null
  then
    select FIPE_RK_seq.nextval
    into  :new.FIPE_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger FIPE_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.FIPE_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_FIN_PERIODS
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
create or replace public synonym OM_FIN_PERIODS FOR OM.OM_FIN_PERIODS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_FIN_PERIODS TO OMSERVICE WITH GRANT OPTION;

