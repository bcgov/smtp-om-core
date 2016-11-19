CREATE OR REPLACE PACKAGE BODY OM.om_log_batch_utl IS
--
---------------------
-- PRIVATE FUNCTIONS
---------------------
--
---------------------
-- PUBLIC FUNCTIONS
---------------------
--
--*****************************************************************************
--* Function:    fn_warnings_exist
--* Purpose:     Gets the value of global warning flag
--*****************************************************************************
   FUNCTION fn_warnings_exist
      RETURN BOOLEAN IS
   BEGIN
      RETURN (gb_warning_flag);
   END fn_warnings_exist;
--
--*****************************************************************************
--* Function:    fn_errors_exist
--* Purpose:     Gets the value of global error flag
--*****************************************************************************
   FUNCTION fn_errors_exist
      RETURN BOOLEAN IS
   BEGIN
      RETURN (gb_error_flag);
   END fn_errors_exist;
--
--*****************************************************************************
--* Function:    fn_stop_execution
--* Purpose:     Gets the value of global stop execution flag
--*****************************************************************************
   FUNCTION fn_stop_execution
      RETURN BOOLEAN IS
   BEGIN
      RETURN (gb_stop_execution_flag);
   END fn_stop_execution;
--
--*****************************************************************************
--* Function:    fn_return_code_ok
--* Purpose:     Gets the value of return code for normal completion
--*****************************************************************************
   FUNCTION fn_return_code_ok
      RETURN st_return_code IS
   BEGIN
      RETURN ('0');
   END fn_return_code_ok;
--
--*****************************************************************************
--* Function:    fn_return_code_ok
--* Purpose:     gets the value of return code for completion with warnings
--*****************************************************************************
   FUNCTION fn_return_code_warning
      RETURN st_return_code IS
   BEGIN
      RETURN ('1');
   END fn_return_code_warning;
--
--*****************************************************************************
--* Function:    fn_return_code_error
--* Purpose:     gets the value of return code for completion with errors
--*****************************************************************************
   FUNCTION fn_return_code_error
      RETURN st_return_code IS
   BEGIN
      RETURN ('2');
   END fn_return_code_error;
--
----------------------
-- PRIVATE PROCEDURES
----------------------
--
--*****************************************************************************
--* Procedure:   prc_set_stop_execution_on
--* Purpose:     set stop execution flag on
--*****************************************************************************
   PROCEDURE prc_set_stop_execution_on IS
   BEGIN
      gb_stop_execution_flag := TRUE;
   END prc_set_stop_execution_on;
--
--*****************************************************************************
--* Procedure:   prc_set_stop_execution_off
--* Purpose:     set stop execution flag off
--*****************************************************************************
   PROCEDURE prc_set_stop_execution_off IS
   BEGIN
      gb_stop_execution_flag := FALSE;
   END prc_set_stop_execution_off;
--
----------------------
-- PUBLIC PROCEDURES
----------------------
--
--*****************************************************************************
--* Procedure:   prc_set_warning_on
--* Purpose:     set warning flag on
--*****************************************************************************
   PROCEDURE prc_set_warning_on IS
   BEGIN
      gb_warning_flag := TRUE;
   END prc_set_warning_on;
--
--*****************************************************************************
--* Procedure:   prc_set_warning_off
--* Purpose:     set warning flag off
--*****************************************************************************
   PROCEDURE prc_set_warning_off IS
   BEGIN
      gb_warning_flag := FALSE;
   END prc_set_warning_off;
--
--*****************************************************************************
--* Procedure:   prc_set_error_on
--* Purpose:     set error flag on
--*****************************************************************************
   PROCEDURE prc_set_error_on IS
   BEGIN
      gb_error_flag := TRUE;
   END prc_set_error_on;
--
--*****************************************************************************
--* Procedure:   prc_set_error_off
--* Purpose:     set error flag off
--*****************************************************************************
   PROCEDURE prc_set_error_off IS
   BEGIN
      gb_error_flag := FALSE;
   END prc_set_error_off;
--
--*****************************************************************************
--* Procedure:  prc_start_package
--* Purpose:    performs standard set of initialization steps for package run
--*****************************************************************************
--
   PROCEDURE prc_start_package (
      pv_application_name_in   IN   om_interface_logs.application_name%TYPE,
      pv_package_name_in       IN   om_interface_logs.package_name%TYPE,
      pv_ver_rel_num_in        IN   VARCHAR2,
      pv_ver_rel_date_in       IN   VARCHAR2,
      pv_procedure_name_in     IN   om_interface_logs.procedure_name%TYPE,
      pv_parameter_value_in    IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL
   ) IS
   --
   BEGIN
--
--------------------------------
-- housekeeping for batch logging
--------------------------------
--
      om_interface_log.prc_set_run_id (om_interface_log.fn_next_run_id);   -- set current run id
      om_interface_log.prc_set_application_name (UPPER (pv_application_name_in));   -- set application name
      om_interface_log.prc_set_package_name (UPPER (pv_package_name_in));   -- set package name
      om_interface_log.prc_set_parameter_value (pv_parameter_value_in);   -- set parameter value
--
----------------------------------------------------------------
-- initialize recording of warnings and errors flag
----------------------------------------------------------------
--
      prc_set_warning_off;
      prc_set_error_off;
--
---------------------------------------------------------
-- initialize information about this module in V$SESSION
---------------------------------------------------------
--
      om_interface_log.prc_show_module (pv_package_name_in);
      om_interface_log.prc_show_proc (pv_procedure_name_in);
--
------------------------------------
-- write package start info message
------------------------------------
--
      om_interface_log.prc_log_info (UPPER (pv_procedure_name_in),
                                         'Package processing started: '
                                      || om_interface_log.fn_package_name
                                      || ' v'
                                      || pv_ver_rel_num_in
                                      || '  Last changed on '
                                      || pv_ver_rel_date_in,
                                      pv_parameter_value_in
                                     );
   --
   EXCEPTION
      WHEN OTHERS THEN
         om_log_batch_utl.prc_handle_sql_error ('prc_start_package');
--
   END prc_start_package;
--
--
--*****************************************************************************
--* procedure:  prc_set_normal_end_of_package
--* Purpose:    Handle normal end (success or warnings) of package processing
--*             Also handles end of package with om_log_batch_utl.fn_errors_exist set
--*             to TRUE, which is a slightly different error condition from
--*             the global exception settting of FATAL ERROR. FATAL ERROR
--*             does not turn on om_log_batch_utl.fn_errors_exist and propagates from
--*             subprograms to mainline by re-raising the exception. It also
--*             triggers a rollback and is considered to be a more "serious"
--*             error, whereas om_log_batch_utl.fn_errors_exist can be used for flag
--*             non-fatal errors.
--* See also:   prc_error_end_of_package
--*****************************************************************************
--
   PROCEDURE prc_set_normal_end_of_package (
      pv_procedure_name_in   IN       om_interface_logs.procedure_name%TYPE,
      pv_return_code_out     OUT      st_return_code,
      pv_return_msg_out      OUT      st_return_msg
   ) IS
   BEGIN
--
------------------------------------------------------------------------------------
-- determine run status - either normal or warning or error, return code and message
-- note - error ge_fatal_error is passed through via exception handling
-- ensure that status is processed in error, warning and normal order, so that
-- errors do not override warnings if both are sets of flags are turned on
------------------------------------------------------------------------------------
--
      IF om_log_batch_utl.fn_errors_exist THEN   -- errors found
         --
         pv_return_code_out := om_log_batch_utl.fn_return_code_error;
         pv_return_msg_out :=
               'Package '
            || om_interface_log.fn_package_name
            || '.'
            || UPPER (pv_procedure_name_in)
            || ' ended with errors';
      --
      ELSIF om_log_batch_utl.fn_warnings_exist THEN   -- warnings found
         --
         pv_return_code_out := om_log_batch_utl.fn_return_code_warning;
         pv_return_msg_out :=
               'Package '
            || om_interface_log.fn_package_name
            || '.'
            || UPPER (pv_procedure_name_in)
            || ' ended with warnings';
      --
      ELSE   -- successful completion
         --
         pv_return_code_out := om_log_batch_utl.fn_return_code_ok;
         pv_return_msg_out :=
               'Package '
            || om_interface_log.fn_package_name
            || '.'
            || UPPER (pv_procedure_name_in)
            || ' ended successfully';
      --
      END IF;
--
---------------------------------------------------------
-- reset information about this module in V$SESSION
---------------------------------------------------------
--
      om_interface_log.prc_show_module (NULL);
      om_interface_log.prc_show_proc (NULL);
      om_interface_log.prc_show_proc_step (NULL);
--
-------------------------------------------
-- write final entry into the execution log
-------------------------------------------
--
      om_interface_log.prc_log_info (pv_procedure_name_in,
                                      pv_return_msg_out || ', return code = ' || pv_return_code_out
                                     );
   --
   EXCEPTION
      WHEN OTHERS THEN
         om_log_batch_utl.prc_handle_sql_error ('prc_set_normal_end_of_package');
   --
   END prc_set_normal_end_of_package;
--
--
--*****************************************************************************
--* procedure:  prc_set_error_end_of_package
--* Purpose:    handle end of package run which encountered errors
--*****************************************************************************
--
   PROCEDURE prc_set_error_end_of_package (
      pv_procedure_name_in   IN       om_interface_logs.procedure_name%TYPE,
      pv_return_code_out     OUT      st_return_code,
      pv_return_msg_out      OUT      st_return_msg
   ) IS
   BEGIN
--
---------------------------
-- rollback to last commit
---------------------------
--
--om_log_batch_utl.prc_do_rollback ( pv_procedure_name_in );
--
----------------------------------------
-- set return code and message to error
----------------------------------------
--
      pv_return_code_out := om_log_batch_utl.fn_return_code_error;
      pv_return_msg_out :=
            'Package '
         || om_interface_log.fn_package_name
         || '.'
         || UPPER (pv_procedure_name_in)
         || ' ended with errors';
--
--
---------------------------------------------------------
-- reset information about this module in V$SESSION
---------------------------------------------------------
--
      om_interface_log.prc_show_module (NULL);
      om_interface_log.prc_show_proc (NULL);
      om_interface_log.prc_show_proc_step (NULL);
--
----------------------------------
-- write entry into execution log
----------------------------------
--
      om_interface_log.prc_log_info (pv_procedure_name_in,
                                      pv_return_msg_out || ', return code = ' || pv_return_code_out
                                     );
   --
   EXCEPTION
      WHEN OTHERS THEN
         om_log_batch_utl.prc_handle_sql_error ('prc_set_error_end_of_package');
   --
   END prc_set_error_end_of_package;
--
--
--*****************************************************************************
--* procedure:  prc_truncate_table
--* Purpose:    truncate table, owner parameter is optional
--*****************************************************************************
--
   PROCEDURE prc_truncate_table (
      pv_owner_name_in   IN   all_tables.owner%TYPE,
      pv_table_name_in   IN   all_tables.table_name%TYPE
   ) IS
      --
      v_procedure_name   om_interface_logs.procedure_name%TYPE   := 'prc_truncate_table';
      v_sql              st_sql_string;
   --
   BEGIN
--
----------------------------------
-- build dynamic SQL statement
----------------------------------
--
      v_sql := 'TRUNCATE TABLE ' || pv_owner_name_in || '.' || pv_table_name_in;
--
----------------------------------
-- save dynamic SQL statement
----------------------------------
--
      om_interface_log.prc_set_current_sql_tag (v_sql);
--
---------------------------------------
-- dynamic SQL - always write to trace
---------------------------------------
--
      om_interface_log.prc_log_trace (v_procedure_name, om_interface_log.fn_current_sql_tag);
--
---------------------------------------
-- execute dynamic SQL
---------------------------------------
--
      EXECUTE IMMEDIATE v_sql;
   --
   EXCEPTION
      --
      WHEN OTHERS THEN
         om_log_batch_utl.prc_handle_sql_error (v_procedure_name,
                                                 om_interface_log.fn_current_sql_tag
                                                );
   --
   END prc_truncate_table;
--
--*****************************************************************************
--* procedure:  prc_handle_sql_error
--* Purpose:    Trap SQL error and write it to BATCH_LOGS table
--*             Handle stop execution conditions
--* Parameters: pv_procedure_name_in - name of calling procedure
--*    pv_log_text_in       - custom log text
--*             pb_log_error_in      - generate batch log entry, T/F
--*             pb_stop_execution_in - stop execution, T/F, if F then carry on
--*                                    with module execution
--*****************************************************************************
--
   PROCEDURE prc_handle_sql_error (
      pv_procedure_name_in   IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in         IN   om_interface_logs.log_text%TYPE DEFAULT 'Unknown error',
      pb_log_error_in        IN   BOOLEAN DEFAULT TRUE,
      pb_stop_execution_in   IN   BOOLEAN DEFAULT TRUE
   ) IS
      --
      v_error_message   VARCHAR2 (4000);
   --
   BEGIN
   --
----------------------------------------------
-- capture error message
----------------------------------------------
--
      v_error_message := SUBSTR (SQLERRM, 1, 4000);
--
-----------------------------------------------------------
-- if the invocation is via a stop execution re-raise then
--    re-raise stop execution
-- else
--    process exception depending on input paramaters
-----------------------------------------------------------
--
      IF fn_stop_execution THEN
 ---------------------------------------------
-- if log parm is on then log error messages
---------------------------------------------
         IF pb_log_error_in THEN
            om_interface_log.prc_log_error (pv_procedure_name_in, 'Stop execution raised');
         END IF;
      ELSE
---------------------------------------------
-- if log parm is on then log error messages
---------------------------------------------
         IF pb_log_error_in THEN
            om_interface_log.prc_log_error (pv_procedure_name_in,
                                             'Execution error: ' || pv_log_text_in
                                            );
            om_interface_log.prc_log_error (pv_procedure_name_in,
                                             'Error message: ' || v_error_message
                                            );
         END IF;
      END IF;
--
---------------------------------------------------------------
-- if stop execution is on then raise stop execution exception
---------------------------------------------------------------
      IF pb_stop_execution_in THEN
         prc_stop_execution;
      END IF;
   --
   EXCEPTION
      WHEN OTHERS THEN
         RAISE;
   --
   END prc_handle_sql_error;
--
--*****************************************************************************
--* procedure:  prc_stop_execution
--* Purpose:    Raises stop execution exception
--*****************************************************************************
--
   PROCEDURE prc_stop_execution IS
   --
   BEGIN
   --
----------------------------------------------
-- Set stop execution flag on
-- Flag is used for exiting nested procedures
----------------------------------------------
      prc_set_stop_execution_on;
--
----------------------------------------------
-- Raise global stop execution exception
----------------------------------------------
--
      RAISE ge_stop_execution;
   --
   EXCEPTION
      WHEN OTHERS THEN
         RAISE;
   --
   END prc_stop_execution;
--
END om_log_batch_utl;
/