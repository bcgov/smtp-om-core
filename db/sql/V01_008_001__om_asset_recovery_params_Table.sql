--drop table OM.OM_ASSET_RECOVERY_PARAMS;
--**************************************************************************************
--* SQL script to create OM.OM_ASSET_RECOVERY_PARAMS table, primary key, foreign key(s) and indexes. 
--* This table is built based on Oracle E-Business Suite table CSI.CSI_I_EXTENDED_ATTRIBS
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-07              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_ASSET_RECOVERY_PARAMS
(
  ARPA_RK                 NUMBER(9) not null,
  ASSET_PARAM_CODE        VARCHAR2(240) not null,
  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_ASSET_RECOVERY_PARAMS is 'Represents the user options that are configured in the SAW service catalogue. This table is similar to CSI.CSI_I_EXTENDED_ATTRIBS table in Oracle E-Business Suite. In EBS CSI.CSI_I_EXTENDED_ATTRIBS  maintains a set of default options like general ledger accounts; locator, lot, and serial controls; inter-organization options; costing method; etc. for each organization defined in Oracle Inventory.';
comment on column OM.OM_ASSET_RECOVERY_PARAMS.ARPA_RK is 'A unique system generated identifier for OM_ASSET_RECOVERY_PARAMS. This column was previously CSI.CSI_I_EXTENDED_ATTRIBS.attribute_id in Oracle E-Business suite.'; 
comment on column OM.OM_ASSET_RECOVERY_PARAMS.ASSET_PARAM_CODE  is 'This column stores the list of specific recovery oriented attributes that have been associated with an asset. Parameter code used at CAS are CAS_BPS_COST_CENTRE, CAS_RECOVERY_START_FLAG, CAS_RECOVERY_START_DATE, CAS_RECOVERY_END_DATE, CAS_SYSTEM_RECOVERY_METHOD,CAS_CANCEL_IB_INSTANCE, CAS_RECOVERY_CREDIT_STATUS.';
comment on column OM.OM_ASSET_RECOVERY_PARAMS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_ASSET_RECOVERY_PARAMS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_ASSET_RECOVERY_PARAMS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_ASSET_RECOVERY_PARAMS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_ASSET_RECOVERY_PARAMS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_ASSET_RECOVERY_PARAMS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_ASSET_RECOVERY_PARAMS
  add constraint ARPA_PK primary key (ARPA_RK) 
  using index tablespace OMIDX;
  
/*prompt
prompt Creating sequence ARPA_RK_SEQ
prompt =============================
prompt*/
create sequence OM.ARPA_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger ARPA_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.ARPA_BR_I_TR
 BEFORE INSERT
 ON OM.OM_ASSET_RECOVERY_PARAMS
 FOR EACH ROW
begin
  if :new.ARPA_RK is null
  then
    select ARPA_RK_seq.nextval
    into  :new.ARPA_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger ARPA_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.ARPA_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_ASSET_RECOVERY_PARAMS
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
create or replace public synonym OM_ASSET_RECOVERY_PARAMS FOR OM.OM_ASSET_RECOVERY_PARAMS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_ASSET_RECOVERY_PARAMS TO OMSERVICE WITH GRANT OPTION;
