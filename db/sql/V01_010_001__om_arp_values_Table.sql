/*drop table OM.OM_ARP_VALUES;
drop sequence ARVA_RK_SEQ;
drop trigger ARVA_BR_I_TR;
drop trigger ARVA_AR_IU_TR;
*/
--**************************************************************************************
--* SQL script to create OM.OM_ARP_VALUES table, primary key, foreign key(s) and indexes. 
--* This table is built based on Oracle E-Business Suite table CSI.CSI_IEA_VALUES 
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-08              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_ARP_VALUES
(
  ARVA_RK                 NUMBER(9) not null,
  ASET_RK                 NUMBER(9) not null,
  ARPA_RK                 NUMBER(9) not null,
  ASSET_PARAM_VALUE       VARCHAR2 (240), 
  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_ARP_VALUES is 'Contains the actual values of the asset recovery parameters. This table is similar to CSI.CSI_IEA_VALUES  table in racle E-Business suite.';
comment on column OM.OM_ARP_VALUES.ARVA_RK is 'A unique system generated identifier for OM_ARP_VALUES.'; 
comment on column OM.OM_ARP_VALUES.ASET_RK is 'The foreign key pointing at OM_ASSETS. This column was previously This column was previously CSI.CSI_ITEM_INSTANCES.instance_id in Oracle E-Business suite.';
comment on column OM.OM_ASSET_RECOVERY_PARAMS.ARPA_RK is 'The foreign key pointing at OM_ASSET_RECOVERY_PARAMS. This column was previously CSI.CSI_I_EXTENDED_ATTRIBS.attribute_id in Oracle E-Business suite.'; 
comment on column OM.OM_ARP_VALUES.ASSET_PARAM_VALUE is 'This column stores the Instance Extended Attribute Value. This column stores the value for asset_param_code in OM.OM_ASSET_RECOVERY_PARAMS table. Source of each of the asset_parameter_code is listed in bracket beside the asset_parameter_code: CAS_BPS_COST_CENTRE	(CostCenter.Code in SAW), CAS_RECOVERY_START_FLAG	(Logic to determine the start date is stored in PL/SQL), CAS_RECOVERY_START_DATE (Subscription.StartDate in SAW), CAS_RECOVERY_END_DATE (Subscription.EndDate in SAW), CAS_SYSTEM_RECOVERY_METHOD (Custom Field on Subscription). This column was previously CSI.CSI_IEA_VALUES.attribute_value'; 
comment on column OM.OM_ARP_VALUES.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_ARP_VALUES.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_ARP_VALUES.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_ARP_VALUES.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_ARP_VALUES.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_ARP_VALUES.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_ARP_VALUES
  add constraint ARVA_PK primary key (ARVA_RK)
  using index tablespace OMIDX;
--Foregin key  
alter table OM.OM_ARP_VALUES
  add constraint ARVA_ASET_RK_FK foreign key (ASET_RK)
  references OM.OM_ASSETS (ASET_RK);
create index OM.ARVA_ASET_RK_FK_IX on OM.OM_ARP_VALUES (ASET_RK) 
tablespace OMIDX;  

alter table OM.OM_ARP_VALUES
  add constraint ARVA_ARPA_RK_FK foreign key (ARPA_RK)
  references OM.OM_ASSET_RECOVERY_PARAMS (ARPA_RK);
create index OM.ARVA_ARPA_RK_FK_IX on OM.OM_ARP_VALUES (ARPA_RK) 
tablespace OMIDX; 
  
/*prompt
prompt Creating sequence ARVA_RK_SEQ
prompt =============================
prompt*/
create sequence OM.ARVA_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger ARVA_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.ARVA_BR_I_TR
 BEFORE INSERT
 ON OM.OM_ARP_VALUES
 FOR EACH ROW
begin
  if :new.ARVA_RK is null
  then
    select ARVA_RK_seq.nextval
    into  :new.ARVA_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger ARVA_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.ARVA_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_ARP_VALUES
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
create or replace public synonym OM_ARP_VALUES FOR OM.OM_ARP_VALUES;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_ARP_VALUES TO OMSERVICE WITH GRANT OPTION;
