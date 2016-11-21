/*drop table OM.OM_RECOVERIES cascade constraints;
drop sequence OM.RECO_RK_SEQ;
drop index OM.RECO_SEOF_RK_FK_IX;
drop index OM.RECO_ORDE_RK_FK_IX;
drop index OM.RECO_RECO_FK_IX;
*/
--**************************************************************************************
--* SQL script to create OM.OM_RECOVERIES table, primary key, foreign key(s) and indexes. 
--* This table is built based on Oracle E-Business Suite table CSI_ITEM_INSTANCES
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-04              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_RECOVERIES
(
  RECO_RK                 NUMBER(9) not null,
  
  RUN_ID                  VARCHAR2(100),  -- fk to om_interface log's unique index on run_id
  SET_OF_BOOKS_ID         NUMBER (15),  -- fk to OM.OM_FIN_SETS_OF_BOOKS table' uk
  GL_PERIOD_NAME          VARCHAR2(15), --OM.OM_FIN_PERIODS
  RECOVERY_PERIOD_NAME    VARCHAR2(15), --OM.OM_FIN_PERIODS
  SEOF_RK                 NUMBER(9),
  ASCO_RK                 NUMBER(9),
  ASSET_REFERENCE         VARCHAR2(30),
  ASSET_TYPE              VARCHAR2(100),
  CONSUMPTION_ID          NUMBER(9),  --cas_ib_consumption.consumption_id not mapped
  ADJUSTMENT_ID           NUMBER(9),  --cas_ib_adjustments.adjustment.id not mapped
  QUANTITY                NUMBER(9),
  ORDER_PRICE             NUMBER (9), --changed from VARCHAR2 (240) because it is used in calculation,
  UNIT_OF_MEASURE         VARCHAR2(10),  --originally VARCHAR2(3)
  AMOUNT                  NUMBER (12),
  RECOVERY_TYPE           VARCHAR2 (240),
  EXPENSE_CLIENT          VARCHAR2 (240),
  EXPENSE_RESPONSIBILITY  VARCHAR2 (240),
  EXPENSE_SERVICE_LINE    VARCHAR2 (240),
  EXPENSE_STOB            VARCHAR2 (240),
  EXPENSE_PROJECT         VARCHAR2 (240),
  EXPENSE_CCID            NUMBER (15),  --Key flexfield combination defining column 
  DEFAULT_EXPENSE_FLAG    VARCHAR2(10),
  RECOVERY_CLIENT         VARCHAR2 (240), 
  RECOVERY_RESPONSIBILITY VARCHAR2 (240), 
  RECOVERY_SERVICE_LINE   VARCHAR2 (240), 
  RECOVERY_STOB           VARCHAR2 (240), 
  RECOVERY_PROJECT        VARCHAR2 (240), 
  DISPLAY_NAME            VARCHAR2 (40), 
  --CUSTOMER_TYPE
  COLOUR                  VARCHAR2 (30), 
  ASSET_TAG               VARCHAR2(30),
  ORDER_PO_NUMBER         NUMBER(15),
  REQUEST_NUMBER          NUMBER(9),
  PROCESS_FLAG            VARCHAR2(10),

  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_RECOVERIES is 'Stages the recovery transactions that are to be sent to CAS for GL Recovery or AR Billing.. This table is similar to CASCSI.CAS_IB_RECOVERIES table in CAS. ';
comment on column OM.OM_RECOVERIES.RECO_RK is 'A unique system generated identifier for OM_RECOVERIES.'; 
comment on column OM.OM_RECOVERIES.RUN_ID is 'A foregin key to om_interface log table unique index on run_id';
comment on column OM.OM_RECOVERIES.SET_OF_BOOKS_ID is 'A foregin key to OM.OM_FIN_SETS_OF_BOOKS table unique key';
 /* GL_PERIOD_NAME          VARCHAR2(15), --OM.OM_FIN_PERIODS
  RECOVERY_PERIOD_NAME    VARCHAR2(15), --OM.OM_FIN_PERIODS
  SEOF_RK                 NUMBER(9),
  ASCO_RK                 NUMBER(9),
  ASSET_REFERENCE         VARCHAR2(30),
  ASSET_TYPE              VARCHAR2(100),
  CONSUMPTION_ID          NUMBER(9),  --cas_ib_consumption.consumption_id not mapped
  ADJUSTMENT_ID           NUMBER(9),  --cas_ib_adjustments.adjustment.id not mapped
  QUANTITY                NUMBER(9),
  ORDER_PRICE             NUMBER (9), --changed from VARCHAR2 (240) because it is used in calculation,
  UNIT_OF_MEASURE         VARCHAR2(10),  --originally VARCHAR2(3)
  AMOUNT                  NUMBER (12),
  RECOVERY_TYPE           VARCHAR2 (240),
  EXPENSE_CLIENT          VARCHAR2 (240),
  EXPENSE_RESPONSIBILITY  VARCHAR2 (240),
  EXPENSE_SERVICE_LINE    VARCHAR2 (240),
  EXPENSE_STOB            VARCHAR2 (240),
  EXPENSE_PROJECT         VARCHAR2 (240),
  EXPENSE_CCID            NUMBER (15),  --Key flexfield combination defining column 
  DEFAULT_EXPENSE_FLAG    VARCHAR2(10),
  RECOVERY_CLIENT         VARCHAR2 (240), 
  RECOVERY_RESPONSIBILITY VARCHAR2 (240), 
  RECOVERY_SERVICE_LINE   VARCHAR2 (240), 
  RECOVERY_STOB           VARCHAR2 (240), 
  RECOVERY_PROJECT        VARCHAR2 (240), 
  DISPLAY_NAME            VARCHAR2 (40), 
  --CUSTOMER_TYPE
  COLOUR                  VARCHAR2 (30), 
  ASSET_TAG               VARCHAR2(30),
  ORDER_PO_NUMBER         NUMBER(15),
  REQUEST_NUMBER          NUMBER(9),
  PROCESS_FLAG */
comment on column OM.OM_RECOVERIES.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_RECOVERIES.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_RECOVERIES.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_RECOVERIES.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_RECOVERIES.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_RECOVERIES.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_RECOVERIES
  add constraint RECO_PK primary key (RECO_RK) 
  using index tablespace OMIDX;
--Foregin key  
/*alter table OM.OM_RECOVERIES
  add constraint RECO_SEOF_RK_FK foreign key (SEOF_RK)
  references OM.OM_SERVICE_OFFERINGS (SEOF_RK);
create index OM.RECO_SEOF_RK_FK_IX on OM.OM_RECOVERIES (SEOF_RK) 
tablespace OMIDX;  

alter table OM.OM_RECOVERIES
  add constraint RECO_ORDE_RK_FK foreign key (ORDE_RK)
  references OM.OM_ORDER_DETAILS (ORDE_RK);
create index OM.RECO_ORDE_RK_FK_IX on OM.OM_RECOVERIES (ORDE_RK) 
tablespace OMIDX;

alter table OM.OM_RECOVERIES
  add constraint RECO_RECO_FK foreign key (PREVIOUS_RECO_RK)
  references OM.OM_RECOVERIES (RECO_RK);
create index OM.RECO_RECO_FK_IX on OM.OM_RECOVERIES (PREVIOUS_RECO_RK) 
tablespace OMIDX;  
 */ 
/*prompt
prompt Creating sequence RECO_RK_SEQ
prompt =============================
prompt*/
create sequence OM.RECO_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger RECO_BR_I_TR
prompt ===============================
prompt*/
/*CREATE OR REPLACE TRIGGER OM.RECO_BR_I_TR
 BEFORE INSERT
 ON OM.OM_RECOVERIES
 FOR EACH ROW
begin
  if :new.RECO_RK is null
  then
    select RECO_RK_seq.nextval
    into  :new.RECO_RK
    from dual;
  end if;
end;
/
*/
/*prompt
prompt Creating trigger RECO_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.RECO_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_RECOVERIES
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
create or replace public synonym OM_RECOVERIES FOR OM.OM_RECOVERIES;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_RECOVERIES TO OMSERVICE WITH GRANT OPTION;
