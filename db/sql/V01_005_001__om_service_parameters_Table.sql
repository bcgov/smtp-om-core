/*drop table OM.OM_SERVICE_PARAMETERS;
drop index OM.SEPA_SEOF_RK_FK_IX;
*/
--**************************************************************************************
--* SQL script to create OM.OM_SERVICE_PARAMETERS table, primary key, foreign key(s) and indexes.  
--* This table is built based on Oracle E-Business Suite table MTL_DESCR_ELEMENT_VALUES
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-04              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_SERVICE_PARAMETERS
(
  SEPA_RK              NUMBER(9) not null,
  PARAMETER_NAME       VARCHAR2 (30), 
  PARAMETER_VALUE      VARCHAR2 (30), 
  SEOF_RK              NUMBER(9) not null,
  CRE_USER             VARCHAR2(30) not null,
  CRE_SRC              VARCHAR2(100) not null,
  CRE_TMSTMP           TIMESTAMP(6) not null,
  UPD_USER             VARCHAR2(30) not null,
  UPD_SRC              VARCHAR2(100) not null,
  UPD_TMSTMP           TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_SERVICE_PARAMETERS is 'This table holds the individual details of the orders (Request details in SAW). This table is similar to MTL_DESCR_ELEMENT_VALUES table in Oracle E-Business Suite. In EBS MTL_DESCR_ELEMENT_VALUES stores the descriptive element values for a specific item. When an item is associated with a particular item catalog group, one row per descriptive element (for that catalog group) is inserted into this table.';
comment on column OM.OM_SERVICE_PARAMETERS.SEPA_RK is 'A unique system generated identifier for OM_SERVICE_PARAMETERS. Oracle E-Business suite has composite primary key comprising of INV.MTL_DESCR_ELEMENT_VALUES.INVENTORY_ITEM_ID and INV.MTL_DESCR_ELEMENT_VALUES.ELEMENT_NAME. This surrogate key replaces the composite primary key in Oracle EBS. '; 
comment on column OM.OM_SERVICE_PARAMETERS.PARAMETER_NAME is 'The name of the parameter';
comment on column OM.OM_SERVICE_PARAMETERS.PARAMETER_VALUE is 'The value of the parameter when the service request is submitted.';
comment on column OM.OM_SERVICE_PARAMETERS.SEOF_RK is 'The foreign key pointing at OM_SERVICE_OFFERINGS. This column is similar to MTL_SYSTEM_ITEMS_B.inventory_item_id in Oracle EBS';
comment on column OM.OM_SERVICE_PARAMETERS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_SERVICE_PARAMETERS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_SERVICE_PARAMETERS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_SERVICE_PARAMETERS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_SERVICE_PARAMETERS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_SERVICE_PARAMETERS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_SERVICE_PARAMETERS
  add constraint SEPA_PK primary key (SEPA_RK) 
  using index tablespace OMIDX;
--Foregin key  
alter table OM.OM_SERVICE_PARAMETERS
  add constraint SEPA_SEOF_RK_FK foreign key (SEOF_RK)
  references OM.OM_SERVICE_OFFERINGS (SEOF_RK);
create index OM.SEPA_SEOF_RK_FK_IX on OM.OM_SERVICE_PARAMETERS (SEOF_RK) 
tablespace OMIDX;  
  
/*prompt
prompt Creating sequence SEPA_RK_SEQ
prompt =============================
prompt*/
create sequence OM.SEPA_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger SEPA_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.SEPA_BR_I_TR
 BEFORE INSERT
 ON OM.OM_SERVICE_PARAMETERS
 FOR EACH ROW
begin
  if :new.SEPA_RK is null
  then
    select SEPA_RK_seq.nextval
    into  :new.SEPA_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger SEPA_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.SEPA_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_SERVICE_PARAMETERS
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
create or replace public synonym OM_SERVICE_PARAMETERS FOR OM.OM_SERVICE_PARAMETERS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_SERVICE_PARAMETERS TO OMSERVICE WITH GRANT OPTION;
