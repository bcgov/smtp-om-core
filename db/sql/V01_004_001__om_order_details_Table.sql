--drop table OM.OM_ORDER_DETAILS;
--**************************************************************************************
--* SQL script to create OM.OM_ORDER_DETAILS table, primary key, foreign key(s) and indexes.  
--* This table is built based on Oracle E-Business Suite table OE_ORDER_LINES_ALL
--* Revision Log
--* Version#   Date        FogBugz#    Revision Description                   Revised By
--* 01         2016-11-02              Created the script                     James Jose
--**************************************************************************************
create table OM.OM_ORDER_DETAILS
(
  ORDE_RK              NUMBER(9) not null,
  REQUEST_NUMBER       NUMBER(9) not null, 
  CUST_PO_NUMBER       VARCHAR2 (50),
  CRE_USER             VARCHAR2(30) not null,
  CRE_SRC              VARCHAR2(100) not null,
  CRE_TMSTMP           TIMESTAMP(6) not null,
  UPD_USER             VARCHAR2(30) not null,
  UPD_SRC              VARCHAR2(100) not null,
  UPD_TMSTMP           TIMESTAMP(6) not null)

  tablespace OMDATA;
 --Add comments on table and columns  
comment on table OM.OM_ORDER_DETAILS is 'This table holds the individual details of the orders (Request details in SAW). This table is similar to OE_ORDER_LINES_ALL table in Oracle E-Business Suite.';
comment on column OM.OM_ORDER_DETAILS.ORDE_RK is 'A unique system generated identifier for OM_ORDER_DETAILS. This column is similar to OE_ORDER_LINES_ALL.line_id in Oracle E-Business suite.'; 
comment on column OM.OM_ORDER_DETAILS.REQUEST_NUMBER is 'This column stores the primary key of the SAW request.';
comment on column OM.OM_ORDER_DETAILS.CUST_PO_NUMBER is 'Customer Purchase Order Number.'; 
comment on column OM.OM_ORDER_DETAILS.CRE_USER is 'Userid of the user who created the record.';           
comment on column OM.OM_ORDER_DETAILS.CRE_SRC is 'The identifier of the system or system component that created the record.';              
comment on column OM.OM_ORDER_DETAILS.CRE_TMSTMP is 'The date, time (with fractions of seconds) when the record was created.';          
comment on column OM.OM_ORDER_DETAILS.UPD_USER is 'Userid of the user who last updated the record.';             
comment on column OM.OM_ORDER_DETAILS.UPD_SRC is  'The identifier of the system or system component that last updated the record.';             
comment on column OM.OM_ORDER_DETAILS.UPD_TMSTMP is 'The date, time (with fractions of seconds) when the record was last updated.';  

--Add Constraints
alter table OM.OM_ORDER_DETAILS
  add constraint ORDE_PK primary key (ORDE_RK) 
  using index tablespace OMIDX;
  
/*prompt
prompt Creating sequence ORDE_RK_SEQ
prompt =============================
prompt*/
create sequence OM.ORDE_RK_SEQ
minvalue 1
maxvalue 9999999999999999999999999999
start with 1
increment by 1
cache 20;

/*prompt
prompt Creating trigger ORDE_BR_I_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.ORDE_BR_I_TR
 BEFORE INSERT
 ON OM.OM_ORDER_DETAILS
 FOR EACH ROW
begin
  if :new.ORDE_RK is null
  then
    select ORDE_RK_seq.nextval
    into  :new.ORDE_RK
    from dual;
  end if;
end;
/
/*prompt
prompt Creating trigger ORDE_AR_IU_TR
prompt ===============================
prompt*/
CREATE OR REPLACE TRIGGER OM.ORDE_AR_IU_TR
 BEFORE INSERT OR UPDATE
 ON OM.OM_ORDER_DETAILS
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
create or replace public synonym OM_ORDER_DETAILS FOR OM.OM_ORDER_DETAILS;

GRANT ALTER, DELETE, INDEX, INSERT, REFERENCES, SELECT, UPDATE ON OM.OM_ORDER_DETAILS TO OMSERVICE WITH GRANT OPTION;
