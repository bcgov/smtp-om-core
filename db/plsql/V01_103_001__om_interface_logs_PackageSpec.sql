CREATE OR REPLACE PACKAGE OM.om_interface_log IS
--$Header:   om_interface_logs_packagespec   1.0   2016/11/14
--******************************************************************************
--*
--* Application:   Order Management
--* Program:       OM Recovery
--*
--* Title:         PL/SQL Batch Logging Utility Package
--*
--* Purpose:       Provide general utility to handle logging from batch PL/SQL packages
--*
--* Parameters  :  As documented in package functions and procedures
--*
--* Tables Accessed:     om_interface_logS - output log table
--*
--* Sequences Accessed:  CAS_INTERFACELOG_LOG_ID_SEQ - sequence for log_id generation
--*                      CAS_INTERFACELOG_RUN_ID_SEQ - sequence for run_id generation
--*
--* Maintenance Log
--* Ver     Date         Description
--* ----------------------------------------------------------------------------
--* 1.0     2006/04/01   Petr Schmidt - Created by Petr and adopted by Wendm.
--*
--******************************************************************************
--
-------------------
-- SUBTYPES
-------------------
--
   SUBTYPE st_sql_string IS VARCHAR2 (4000);   -- define subtype for strings containing SQL statements
--
-------------------
-- CONSTANTS
-------------------
--
-------------------
-- VARIABLES
-------------------
--
   gn_run_id                  om_interface_logs.run_id%TYPE             := -1;   -- current run_id
   gv_application_name        om_interface_logs.application_name%TYPE   := 'Unknown';   -- current application
   gv_package_name            om_interface_logs.package_name%TYPE       := 'Unknown';   -- current package name
   gv_procedure_name          om_interface_logs.procedure_name%TYPE     := 'Unknown';   -- current procedure or function name
   gv_parameter_value         om_interface_logs.parameter_value%TYPE    := NULL;   -- current parameter value
   gv_current_sql_tag         st_sql_string                              := 'Unknown';   -- current SQL statement
   gb_is_appl_trace_enabled   BOOLEAN                                    := FALSE;   -- for writing trace logs, disabled by default
   gd_creation_date           DATE                                       := NULL;   -- for updating WHO cols
--
-------------------
-- EXCEPTIONS
-------------------
--
-------------------
-- FUNCTIONS
-------------------
--
-- get current run_id
   FUNCTION fn_run_id
      RETURN om_interface_logs.run_id%TYPE;
--
-- get next run_id
   FUNCTION fn_next_run_id
      RETURN om_interface_logs.run_id%TYPE;
--
-- get current application name
   FUNCTION fn_application_name
      RETURN om_interface_logs.application_name%TYPE;
--
-- get current package name
   FUNCTION fn_package_name
      RETURN om_interface_logs.package_name%TYPE;
--
-- get current SQL tag
   FUNCTION fn_current_sql_tag
      RETURN st_sql_string;
--
-- get next log_id for BATCH_LOG entry
   FUNCTION fn_next_inlo_rk
      RETURN om_interface_logs.inlo_rk%TYPE;
--
-- get various log entry types - info, warning, error and trace
   FUNCTION fn_log_type_info
      RETURN om_interface_logs.log_entry_type%TYPE;
   FUNCTION fn_log_type_warning
      RETURN om_interface_logs.log_entry_type%TYPE;
   FUNCTION fn_log_type_error
      RETURN om_interface_logs.log_entry_type%TYPE;
   FUNCTION fn_log_type_trace
      RETURN om_interface_logs.log_entry_type%TYPE;
--
-------------------
-- PROCEDURES
-------------------
--
-- set current run_id
   PROCEDURE prc_set_run_id (pn_run_id_in IN om_interface_logs.run_id%TYPE);
--
-- set current application_name
   PROCEDURE prc_set_application_name (pv_application_name_in IN om_interface_logs.application_name%TYPE);
--
-- set current package_name
   PROCEDURE prc_set_package_name (pv_package_name_in IN om_interface_logs.package_name%TYPE);
--
-- set current SQL tag
   PROCEDURE prc_set_current_sql_tag (
      pv_current_sql_tag_in   IN   st_sql_string,
      pb_show_proc_step_in    IN   BOOLEAN DEFAULT TRUE
   );
--
-- set current parameter value
   PROCEDURE prc_set_parameter_value (pv_parameter_value_in IN om_interface_logs.parameter_value%TYPE);
--
-- show module progress in v$session
   PROCEDURE prc_show_module (pv_module_in IN VARCHAR2);
   PROCEDURE prc_show_proc (pv_proc_in IN VARCHAR2);
   PROCEDURE prc_show_proc_step (pv_proc_step_in IN VARCHAR2);
--
-- create log entries by type - informational, error, warning and trace
   PROCEDURE prc_log_info (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   );
   PROCEDURE prc_log_error (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   );
   PROCEDURE prc_log_warning (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   );
   PROCEDURE prc_log_trace (
      pv_procedure_name_in    IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in          IN   om_interface_logs.log_text%TYPE,
      pv_parameter_value_in   IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL,
      pn_key1_id_in           IN   om_interface_logs.key1_id%TYPE DEFAULT NULL,
      pn_key2_id_in           IN   om_interface_logs.key2_id%TYPE DEFAULT NULL
   );
--
-- create log entry for procedure start and end
   PROCEDURE prc_log_procedure_start (pv_procedure_name_in IN om_interface_logs.procedure_name%TYPE);
   PROCEDURE prc_log_procedure_end (pv_procedure_name_in IN om_interface_logs.procedure_name%TYPE);
--
END om_interface_log;
/