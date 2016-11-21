/*drop table OM.OM_ASSETS;
drop index OM.ASET_SEOF_RK_FK_IX;
drop index OM.ASET_ORDE_RK_FK_IX;
drop index OM.ASET_ASET_FK_IX;
*/
--**************************************************************************************
--* SQL script to create OM.OM_ASSETS table, primary key, foreign key(s) and indexes. 
--* This table is built based on Oracle E-Business Suite table CSI_ITEM_INSTANCES
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-04              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_ASSETS
(
  ASET_RK                 NUMBER(9) not null,
  SEOF_RK                 NUMBER(9) not null, --Last Updated By Offering Id
  ORDE_RK                 NUMBER(9) not null,
  PREVIOUS_ASET_RK        NUMBER(9),
  ASSET_REFERENCE         VARCHAR2(30) not null,
  ASSET_TYPE              VARCHAR2(100),
  ASSET_TAG               VARCHAR2(30),
  QUANTITY                NUMBER(9)  not null, 
  UNIT_OF_MEASURE         VARCHAR2(10) not null,  --originally VARCHAR2(3)
  EXPENSE_CLIENT          VARCHAR2 (240),
  EXPENSE_RESPONSIBILITY  VARCHAR2 (240),
  EXPENSE_SERVICE_LINE    VARCHAR2 (240),
  EXPENSE_STOB            VARCHAR2 (240),
  EXPENSE_PROJECT         VARCHAR2 (240),
  EXPENSE_CCID            VARCHAR2 (240), 
  DESCRIPTION             VARCHAR2 (240),
  RECOVERY_FREQUENCY      VARCHAR2 (240),
  ORDER_PRICE             NUMBER (9) , --changed from VARCHAR2 (240) because it is used in calculation,
  OWNER_PARTY_ID          NUMBER (15),-- De-normalized Column for Instance Owner Party Identifier 
  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_ASSETS is 'Represents a device or actual service that is associated with a subscription. This table is similar to CSI.CSI_ITEM_INSTANCES table in Oracle E-Business Suite. In EBS CSI.CSI_ITEM_INSTANCES stores the Item Instaces details.';
comment on column OM.OM_ASSETS.ASET_RK is 'A unique system generated identifier for OM_ASSETS. This column was previously CSI.CSI_ITEM_INSTANCES.instance_id in Oracle E-Business suite.'; 
comment on column OM.OM_ASSETS.SEOF_RK is 'The foreign key pointing at OM_SERVICE_OFFERINGS. This column was previously MTL_SYSTEM_ITEMS_B.inventory_item_id in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.ORDE_RK is 'The foreign key pointing at OM.OM_ORDER_DETAILS.' ;              
comment on column OM.OM_ASSETS.PREVIOUS_ASET_RK is 'The foreign key representing previous version of Asset.';
comment on column OM.OM_ASSETS.ASSET_REFERENCE is 'SAW key (Subscription.Id or Request.Id) referencing asset. This column was previously CSI.CSI_ITEM_INSTANCES.instance_number in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.ASSET_TYPE is 'Type of asset: one time (Request) or recurring (Subscription). Logic to determine the asset type is coded in pl/sql package';
comment on column OM.OM_ASSETS.ASSET_TAG is 'Business key to identify CI. It is sourced from Subscription.AssetTag in SAW. This column was previously CSI.CSI_ITEM_INSTANCES.external_reference in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.QUANTITY is 'Order quantity. It is sourced from Request.User Options.Quantity (or always 1), Subscription.User Options.Quantity (or always 1) in SAW. This column was previously CSI.CSI_ITEM_INSTANCES.quantity in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.UNIT_OF_MEASURE is 'This indicate how the asset is measured (e.g Monthly, GB). This column was previously CSI.CSI_ITEM_INSTANCES.unit_of_measure in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.EXPENSE_CLIENT is 'This column stores the value user entered for Expense Client Coding.It is sourced from custom fields in SAW, Subscription.Client or Request.Client. This column was previously CSI.CSI_ITEM_INSTANCES.attribute1 in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.EXPENSE_RESPONSIBILITY is 'This column stores the value user entered for Expense Responsibility Coding.It is sourced from custom fields in SAW, Subscription.Responsibility or Request.Responsibility. This column was previously CSI.CSI_ITEM_INSTANCES.attribute2 in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.EXPENSE_SERVICE_LINE is 'This column stores the value user entered for Expense Service Line Coding.It is sourced from custom fields in SAW, Subscription.Service Line or Request.Service Line. This column was previously CSI.CSI_ITEM_INSTANCES.attribute3 in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.EXPENSE_STOB is 'This column stores the value of STOB Coding.Logic to determine stob is defined in the pl/sql package . This column was previously CSI.CSI_ITEM_INSTANCES.attribute4 in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.EXPENSE_PROJECT is 'This column stores the value user entered for Expense Project Coding.It is sourced from custom fields in SAW, Subscription.Project or Request.Project. This column was previously CSI.CSI_ITEM_INSTANCES.attribute5 in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.DESCRIPTION is 'This column stores the value of Offering description. It is sourced from Offering.Display Label in SAW. This column was previously CSI.CSI_ITEM_INSTANCES.attribute7 in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.RECOVERY_FREQUENCY is 'This column stores the value of recovery frequency. It is sourced from Subscription.RecurringPeriod in SAW. This column was previously CSI.CSI_ITEM_INSTANCES.attribute12 in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.ORDER_PRICE is 'This column stores the value of order price. It is sourced from Subscription.FrontCost, Subscription.RecurringCost, Request.Cost in SAW. This column was previously CSI.CSI_ITEM_INSTANCES.attribute13 in Oracle E-Business suite.';
comment on column OM.OM_ASSETS.OWNER_PARTY_ID is 'De-normalized Column for Instance Owner Party Identifier.'; 
comment on column OM.OM_ASSETS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_ASSETS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_ASSETS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_ASSETS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_ASSETS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_ASSETS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_ASSETS
  add constraint ASET_PK primary key (ASET_RK) 
  using index tablespace OMIDX;
--Foregin key  
alter table OM.OM_ASSETS
  add constraint ASET_SEOF_RK_FK foreign key (SEOF_RK)
  references OM.OM_SERVICE_OFFERINGS (SEOF_RK);
create index OM.ASET_SEOF_RK_FK_IX on OM.OM_ASSETS (SEOF_RK) 
tablespace OMIDX;  

alter table OM.OM_ASSETS
  add constraint ASET_ORDE_RK_FK foreign key (ORDE_RK)
  references OM.OM_ORDER_DETAILS (ORDE_RK);
create index OM.ASET_ORDE_RK_FK_IX on OM.OM_ASSETS (ORDE_RK) 
tablespace OMIDX;

alter table OM.OM_ASSETS
  add constraint ASET_ASET_FK foreign key (PREVIOUS_ASET_RK)
  references OM.OM_ASSETS (ASET_RK);
create index OM.ASET_ASET_FK_IX on OM.OM_ASSETS (PREVIOUS_ASET_RK) 
tablespace OMIDX;  
  
/*prompt
prompt Creating sequence ASET_RK_SEQ
prompt =============================
prompt*/
create sequence OM.ASET_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger ASET_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.ASET_BR_I_TR
 BEFORE INSERT
 ON OM.OM_ASSETS
 FOR EACH ROW
begin
  if :new.ASET_RK is null
  then
    select ASET_RK_seq.nextval
    into  :new.ASET_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger ASET_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.ASET_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_ASSETS
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
create or replace public synonym OM_ASSETS FOR OM.OM_ASSETS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_ASSETS TO OMSERVICE WITH GRANT OPTION;
