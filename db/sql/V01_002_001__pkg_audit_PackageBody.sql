CREATE OR REPLACE PACKAGE BODY OM.PKG_AUDIT IS

--****************************************************************************************************
--* PLSQL package to support the audit columns functionality. 
--* 
--* Revision Log
--* Version#     Date        FogBugz#    Revision Description                         Revised By
--* 01           2016-11-02              Created the package body                     James Jose
--****************************************************************************************************


FUNCTION FNC_GET_TRANSACTION_SOURCE( p_new_value VARCHAR2 := NULL
                                   , p_old_value VARCHAR2 := NULL
                                   )
 RETURN VARCHAR2
 IS
begin
    return 'Unknown';
  end;
end pkg_audit;
/