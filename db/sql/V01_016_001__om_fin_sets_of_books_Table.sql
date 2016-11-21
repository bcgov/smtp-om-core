/*drop table OM.OM_FIN_SETS_OF_BOOKS cascade constraints;
drop index OM.FSOB_FPSE_RK_FK_IX;

drop index OM.FSOB_FSOB_FK_IX;
*/
--**************************************************************************************
--* SQL script to create OM.OM_FIN_SETS_OF_BOOKS table, primary key, foreign key(s), synonyms and indexes. 
--* This table is built based on CAS table CAS_GENERIC_TABLE_DETAILS
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-09              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_FIN_SETS_OF_BOOKS
(
  FSOB_RK                 NUMBER(9)     not null,
  FPSE_RK                 NUMBER(9)     not null,
  SET_OF_BOOKS_ID         NUMBER (15)   not null,
  CHART_OF_ACCOUNTS_ID    NUMBER (15)   not null,
  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_FIN_SETS_OF_BOOKS is 'Represents the GL Periods as stored in the the Oracle E-Business Suite at CAS. OM_FIN_SETS_OF_BOOKS stores information about the accounting periods defined in E-Business suite. Each row includes the start date and end date of the period, the fiscal year, and other information. There is a one-to-many relationship between a row in the OM_FIN_SETS_OF_BOOKS_SETS table and rows in this table.';
comment on column OM.OM_FIN_SETS_OF_BOOKS.FSOB_RK is 'A unique system generated identifier for OM_FIN_SETS_OF_BOOKS.'; 
comment on column OM.OM_FIN_SETS_OF_BOOKS.FPSE_RK is 'A foregin key pointing to OM.OM_FIN_PERIOD_SETS table';  
comment on column OM.OM_FIN_SETS_OF_BOOKS.SET_OF_BOOKS_ID is 'Accounting books defining column. Source refers to CAS DW not EBS'; 
comment on column OM.OM_FIN_SETS_OF_BOOKS.CHART_OF_ACCOUNTS_ID is 'Key flexfield structure defining column. Source refers to CAS DW not EBS'; 

comment on column OM.OM_FIN_SETS_OF_BOOKS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_FIN_SETS_OF_BOOKS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_FIN_SETS_OF_BOOKS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the FSOBrd was created.';          
comment on column OM.OM_FIN_SETS_OF_BOOKS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_FIN_SETS_OF_BOOKS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_FIN_SETS_OF_BOOKS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the FSOBrd was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_FIN_SETS_OF_BOOKS
  add constraint FSOB_PK primary key (FSOB_RK) 
  using index tablespace OMIDX;

create unique index OM.FSOB_IDX_U1 on OM.OM_FIN_SETS_OF_BOOKS
(SET_OF_BOOKS_ID)
LOGGING
TABLESPACE OMIDX;

--Foregin key  
alter table OM.OM_FIN_SETS_OF_BOOKS
  add constraint FSOB_FPSE_RK_FK foreign key (FPSE_RK)
  references OM.OM_FIN_PERIOD_SETS (FPSE_RK);
create index OM.FSOB_FPSE_RK_FK_IX on OM.OM_FIN_SETS_OF_BOOKS (FPSE_RK) 
tablespace OMIDX;  
 
/*prompt
prompt Creating sequence FSOB_RK_SEQ
prompt =============================
prompt*/
create sequence OM.FSOB_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger FSOB_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.FSOB_BR_I_TR
 BEFORE INSERT
 ON OM.OM_FIN_SETS_OF_BOOKS
 FOR EACH ROW
begin
  if :new.FSOB_RK is null
  then
    select FSOB_RK_seq.nextval
    into  :new.FSOB_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger FSOB_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.FSOB_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_FIN_SETS_OF_BOOKS
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
create or replace public synonym OM_FIN_SETS_OF_BOOKS FOR OM.OM_FIN_SETS_OF_BOOKS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_FIN_SETS_OF_BOOKS TO OMSERVICE WITH GRANT OPTION;

