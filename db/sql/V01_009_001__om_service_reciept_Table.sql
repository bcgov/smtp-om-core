/*drop table OM.OM_SERVICE_RECIEPT;
drop sequence SERE_RK_SEQ;
drop trigger SERE_BR_I_TR;
drop trigger SERE_AR_IU_TR;
*/
--**************************************************************************************
--* SQL script to create OM.OM_SERVICE_RECIEPT table, primary key, foreign key(s) and indexes. 
--* This table is built based on CAS custom table cascsi.CAS_IB_SERVICE_RECIEPT
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-07              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_SERVICE_RECIEPT
(
  SERE_RK                 NUMBER(9) not null,
  ASET_RK                 NUMBER(9) not null,
  SERVICE_RECEIPT_STATUS  VARCHAR2(240) not null,
  CRE_USER                VARCHAR2(30) not null,
  CRE_SRC                 VARCHAR2(100) not null,
  CRE_TMSTMP              TIMESTAMP(6) not null,
  UPD_USER                VARCHAR2(30) not null,
  UPD_SRC                 VARCHAR2(100) not null,
  UPD_TMSTMP              TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_SERVICE_RECIEPT is 'Used to store the acknowledgement that an individual has confirmed receipt of their service. This table is similar to cascsi.CAS_IB_SERVICE_RECIEPT table in CAS.';
comment on column OM.OM_SERVICE_RECIEPT.SERE_RK is 'A unique system generated identifier for OM_SERVICE_RECIEPT. This column was previously cascsi.CAS_IB_SERVICE_RECIEPT.service_receipt_id.'; 
comment on column OM.OM_SERVICE_RECIEPT.ASET_RK is 'The foreign key pointing at OM_ASSETS. This column was previously This column was previously CSI.CSI_ITEM_INSTANCES.instance_id in Oracle E-Business suite.';
comment on column OM.OM_SERVICE_RECIEPT.SERVICE_RECEIPT_STATUS is 'This column is sourced from custom field in SAW and must be RECEIVED, NOT REQUIRED, DEEMED RECEIVED.';

comment on column OM.OM_SERVICE_RECIEPT.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_SERVICE_RECIEPT.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_SERVICE_RECIEPT.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_SERVICE_RECIEPT.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_SERVICE_RECIEPT.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_SERVICE_RECIEPT.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
--Primary key
alter table OM.OM_SERVICE_RECIEPT
  add constraint SERE_PK primary key (SERE_RK)
  using index tablespace OMIDX;
--Foregin key  
alter table OM.OM_SERVICE_RECIEPT
  add constraint SERE_ASET_RK_FK foreign key (ASET_RK)
  references OM.OM_ASSETS (ASET_RK);
create index OM.SERE_ASET_RK_FK_IX on OM.OM_SERVICE_RECIEPT (ASET_RK) 
tablespace OMIDX;  
  
/*prompt
prompt Creating sequence SERE_RK_SEQ
prompt =============================
prompt*/
create sequence OM.SERE_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger SERE_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.SERE_BR_I_TR
 BEFORE INSERT
 ON OM.OM_SERVICE_RECIEPT
 FOR EACH ROW
begin
  if :new.SERE_RK is null
  then
    select SERE_RK_seq.nextval
    into  :new.SERE_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger SERE_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.SERE_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_SERVICE_RECIEPT
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
create or replace public synonym OM_SERVICE_RECIEPT FOR OM.OM_SERVICE_RECIEPT;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_SERVICE_RECIEPT TO OMSERVICE WITH GRANT OPTION;
