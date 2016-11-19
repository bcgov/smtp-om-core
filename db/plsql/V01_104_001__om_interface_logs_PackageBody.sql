CREATE OR REPLACE PACKAGE BODY OM.om_interface_log IS
--
----------------------
-- PRIVATE FUNCTIONS
----------------------
--
----------------------
-- PUBLIC FUNCTIONS
----------------------
--
--*****************************************************************************
--* Function:  fn_run_id
--* Purpose:   Get saved run id for current batch invocation
--*            Returns previously set run id, it does not get a new value!!
--*****************************************************************************
   FUNCTION fn_run_id
      RETURN om_interface_logs.run_id%TYPE IS
   BEGIN
      RETURN (gn_run_id);
   END fn_run_id;
--
--*****************************************************************************
--* Function:  fn_next_run_id
--* Purpose:   Get next value of run id from sequence
--*****************************************************************************
   FUNCTION fn_next_run_id
      RETURN om_interface_logs.run_id%TYPE IS
      n_run_id   om_interface_logs.run_id%TYPE;
   BEGIN
      SELECT inlo_run_id_seq.NEXTVAL--cas_interfacelog_run_id_seq.NEXTVAL
        INTO n_run_id
        FROM DUAL;
      RETURN (n_run_id);
   END fn_next_run_id;
--
--*****************************************************************************
--* Function:  fn_application_name
--* Purpose:   Get application_name for current batch invocation
--*****************************************************************************
   FUNCTION fn_application_name
      RETURN om_interface_logs.application_name%TYPE IS
   BEGIN
      RETURN (gv_application_name);
   END fn_application_name;
--
--*****************************************************************************
--* Function:  fn_package_name
--* Purpose:   Get package_name for current batch invocation
--*****************************************************************************
   FUNCTION fn_package_name
      RETURN om_interface_logs.package_name%TYPE IS
   BEGIN
      RETURN (gv_package_name);
   END fn_package_name;
--
--*****************************************************************************
--* Function:  fn_next_inlo_rk
--* Purpose:   Get next inlo_rk for new log entry
--*****************************************************************************
   FUNCTION fn_next_inlo_rk
      RETURN om_interface_logs.inlo_rk%TYPE IS
      n_inlo_rk   om_interface_logs.inlo_rk%TYPE;
   BEGIN
      SELECT om.inlo_rk_seq.NEXTVAL --cas_interfacelog_inlo_rk_seq.NEXTVAL
        INTO n_inlo_rk
        FROM DUAL;
      RETURN (n_inlo_rk);
   END fn_next_inlo_rk;
--
--*****************************************************************************
--* Function:    fn_current_sql_tag
--* Purpose:     Get global variable value with current SQL statement label
--*****************************************************************************
   FUNCTION fn_current_sql_tag
      RETURN st_sql_string IS
   BEGIN
      RETURN (gv_current_sql_tag);
   END fn_current_sql_tag;
--
--*****************************************************************************
--* Function:    fn_log_type_info
--* Purpose:     Return code used for error log entries
--*****************************************************************************
   FUNCTION fn_log_type_info
      RETURN om_interface_logs.log_entry_type%TYPE IS
   BEGIN
      RETURN ('I');
   END fn_log_type_info;
--
--*****************************************************************************
--* Function:    fn_log_type_warning
--* Purpose:     Return code used for error log entries
--*****************************************************************************
   FUNCTION fn_log_type_warning
      RETURN om_interface_logs.log_entry_type%TYPE IS
   BEGIN
      RETURN ('W');
   END fn_log_type_warning;
--
--*****************************************************************************
--* Function:    fn_log_type_error
--* Purpose:     Return code used for error log entries
--*****************************************************************************
   FUNCTION fn_log_type_error
      RETURN om_interface_logs.log_entry_type%TYPE IS
   BEGIN
      RETURN ('E');
   END fn_log_type_error;
--
--*****************************************************************************
--* Function:    get_log_type_trace
--* Purpose:     Return code used for error log entries
--*****************************************************************************
   FUNCTION fn_log_type_trace
      RETURN om_interface_logs.log_entry_type%TYPE IS
   BEGIN
      RETURN ('T');
   END fn_log_type_trace;
--
----------------------
-- PRIVATE PROCEDURES
----------------------
--
--*****************************************************************************
--* Procedure:  prc_insert_log
--* Purpose:    Insert new row into BATCH_LOGS
--* Assumption: Following calls must have been made to setup batch environment:
--*             batch_log.prc_set_run_id
--*             batch_log.prc_set_application_name
--*             batch_log.prc_set_package_name
--*****************************************************************************
   PROCEDURE prc_insert_log (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_log_entry_type_in    IN   om_interface_logs.log_entry_type%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   ) IS
      --
   --PRAGMA AUTONOMOUS_TRANSACTION;   -- suspend main transaction
   --
   BEGIN
      --
      INSERT INTO om_interface_logs
                  (inlo_rk, run_id,
                   log_entry_type, application_name, package_name,
                   procedure_name, /*creation_date,*/ log_text, parameter_value,
                   key1_id, key2_id
                  )
           VALUES (om_interface_log.fn_next_inlo_rk,   -- get value using function call
                                                    om_interface_log.fn_run_id,   -- get value using function call
                   pv_log_entry_type_in, UPPER (fn_application_name),   -- translate to upper case
                                                                     UPPER (fn_package_name),   -- translate to upper case
                   UPPER (pv_procedure_name_in),   -- translate to upper case
                                               -- SYSDATE,   -- SYSDATE
                                                        pv_log_text_in, pv_parameter_value_in,
                   pn_key1_id_in, pn_key2_id_in
                  );
   --
   END prc_insert_log;
--
----------------------
-- PUBLIC PROCEDURES
----------------------
--
--*****************************************************************************
--* Procedure: prc_set_run_id
--* Purpose:   set run id for current batch invocation
--*****************************************************************************
   PROCEDURE prc_set_run_id (pn_run_id_in IN om_interface_logs.run_id%TYPE) IS
   BEGIN
      gn_run_id := pn_run_id_in;
   END prc_set_run_id;
--
--*****************************************************************************
--* Procedure: prc_unset_run_id
--* Purpose:   Unset run id for current batch invocation
--*****************************************************************************
   PROCEDURE prc_unset_run_id IS
   BEGIN
      prc_set_run_id (NULL);
   END prc_unset_run_id;
--
--*****************************************************************************
--* Procedure: prc_set_application_name
--* Purpose:   Set application_name for current batch invocation
--*****************************************************************************
   PROCEDURE prc_set_application_name (
      pv_application_name_in   IN   om_interface_logs.application_name%TYPE
   ) IS
   BEGIN
      gv_application_name := pv_application_name_in;
   END prc_set_application_name;
--
--*****************************************************************************
--* Procedure: prc_set_package_name
--* Purpose:   Set package name for current batch invocation
--*****************************************************************************
   PROCEDURE prc_set_package_name (pv_package_name_in IN om_interface_logs.package_name%TYPE) IS
   BEGIN
      gv_package_name := pv_package_name_in;
   END prc_set_package_name;
--
--*****************************************************************************
--* Procedure: prc_set_parameter_value
--* Purpose:   Set parameter value for current batch invocation
--*****************************************************************************
   PROCEDURE prc_set_parameter_value (
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE
   ) IS
   BEGIN
      gv_parameter_value := pv_parameter_value_in;
   END prc_set_parameter_value;
--
--*****************************************************************************
--* Procedure: prc_show_module
--* Purpose:   Set module name in v$session.module column
--*****************************************************************************
   PROCEDURE prc_show_module (pv_module_in IN VARCHAR2) IS
   BEGIN
      DBMS_APPLICATION_INFO.set_module (UPPER (pv_module_in), NULL);
   END prc_show_module;
--
--*****************************************************************************
--* Procedure: prc_show_proc
--* Purpose:   Set proc name in v$session.action column
--*****************************************************************************
   PROCEDURE prc_show_proc (pv_proc_in IN VARCHAR2) IS
   BEGIN
      DBMS_APPLICATION_INFO.set_action (UPPER (pv_proc_in));
   END prc_show_proc;
--
--*****************************************************************************
--* Procedure: prc_show_proc
--* Purpose:   Set proc name in v$session.client_info column
--*****************************************************************************
   PROCEDURE prc_show_proc_step (pv_proc_step_in IN VARCHAR2) IS
   BEGIN
      DBMS_APPLICATION_INFO.set_client_info (pv_proc_step_in);
   END prc_show_proc_step;
--
--*****************************************************************************
--* Procedure:   prc_set_current_sql_tag
--* Purpose:     Set a global variable to contain current SQL statement label
--*****************************************************************************
--
   PROCEDURE prc_set_current_sql_tag (
      pv_current_sql_tag_in   IN   st_sql_string,
      pb_show_proc_step_in    IN   BOOLEAN DEFAULT TRUE
   ) IS
   BEGIN
      gv_current_sql_tag := pv_current_sql_tag_in;
      IF pb_show_proc_step_in THEN
         prc_show_proc_step (pv_current_sql_tag_in);
      END IF;
   END prc_set_current_sql_tag;
--
--*****************************************************************************
--* Procedure: prc_enable_appl_trace
--* Purpose:   Enable tracing via calls to custom application tracing
--*****************************************************************************
   PROCEDURE prc_enable_appl_trace IS
   BEGIN
      gb_is_appl_trace_enabled := TRUE;
   END prc_enable_appl_trace;
--
--*****************************************************************************
--* Procedure: prc_disable_appl_trace
--* Purpose:   Disable tracing via calls to custom application tracing
--*****************************************************************************
   PROCEDURE prc_disable_appl_trace IS
   BEGIN
      gb_is_appl_trace_enabled := FALSE;
   END prc_disable_appl_trace;
--
--*****************************************************************************
--* Procedure:  prc_log_info
--* Purpose:    Create log entry of type INFORMATIONAL
--*****************************************************************************
   PROCEDURE prc_log_info (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   ) IS
   BEGIN
      prc_insert_log (pv_procedure_name_in,
                      pv_log_text_in,
                      om_interface_log.fn_log_type_info,
                      pv_parameter_value_in,
                      pn_key1_id_in,
                      pn_key2_id_in
                     );
   END prc_log_info;
--
--*****************************************************************************
--* Procedure:  prc_log_warning
--* Purpose:    Create log entry of type WARNING
--*****************************************************************************
   PROCEDURE prc_log_warning (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   ) IS
   BEGIN
      prc_insert_log (pv_procedure_name_in,
                      pv_log_text_in,
                      om_interface_log.fn_log_type_warning,
                      pv_parameter_value_in,
                      pn_key1_id_in,
                      pn_key2_id_in
                     );
   END prc_log_warning;
--
--*****************************************************************************
--* Procedure:  prc_log_trace
--* Purpose:    Create log entry of type TRACE
--*****************************************************************************
   PROCEDURE prc_log_trace (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   ) IS
   BEGIN
      prc_insert_log (pv_procedure_name_in,
                      pv_log_text_in,
                      om_interface_log.fn_log_type_trace,
                      pv_parameter_value_in,
                      pn_key1_id_in,
                      pn_key2_id_in
                     );
   END prc_log_trace;
--
--*****************************************************************************
--* Procedure:  prc_log_error
--* Purpose:    Create log entry of type ERROR
--*****************************************************************************
   PROCEDURE prc_log_error (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   ) IS
   BEGIN
      prc_insert_log (pv_procedure_name_in,
                      pv_log_text_in,
                      om_interface_log.fn_log_type_error,
                      pv_parameter_value_in,
                      pn_key1_id_in,
                      pn_key2_id_in
                     );
   END prc_log_error;
--
--*****************************************************************************
--* procedure:  prc_log_procedure_start
--* Purpose:    log procedure start into batch_logS
--*             optionally used for timing procedures which do not have any commits
--*****************************************************************************
   PROCEDURE prc_log_procedure_start (
      pv_procedure_name_in   IN   om_interface_logs.procedure_name%TYPE
   ) IS
   BEGIN
      prc_log_info (pv_procedure_name_in,
                    'Procedure ' || UPPER (pv_procedure_name_in) || ' started');
   END prc_log_procedure_start;
--
--*****************************************************************************
--* procedure:  prc_log_procedure_end
--* Purpose:    log procedure end into batch_logS
--*             optionally used for timing procedures which do not have any commits
--*****************************************************************************
   PROCEDURE prc_log_procedure_end (pv_procedure_name_in IN om_interface_logs.procedure_name%TYPE) IS
   BEGIN
      prc_log_info (pv_procedure_name_in, 'Procedure ' || UPPER (pv_procedure_name_in) || ' ended');
   END prc_log_procedure_end;
--
END om_interface_log;
/