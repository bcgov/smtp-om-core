CREATE OR REPLACE PACKAGE OM.om_log_batch_utl IS
--$Header:   v01_105_001__om_log_batch_utl_PackageSpec   1.0  2016/11/15
--******************************************************************************
--*
--* Application:   Order Management in ITSM
--* Program:       om_log_batch_utl
--*
--* Title:         Batch PL/SQL Utility Package
--*
--* Purpose:       Provide utility to handle common batch PL/SQL tasks
--*
--* Parameters  :  As documented in package functions and procedures
--*
--* Tables Accessed:     OM_INTERFACE_LOGS - batch log table
--*
--* Sequences Accessed:
--*
--* Maintenance Log
--* Ver     Date         Description
--* ----------------------------------------------------------------------------
--*
--* NOTE: this package was adopted by Wendm Sahle from DW team.
--*       Some of the functions and procedures were taken out since they did
--*       not apply to OFA.
--*
--* 1.0     2006/04/01   Petr Schmidt - Created
--* 
--* 1.0     2016/11/15   James Jose - Refactored for OM stream in SMTP project
--******************************************************************************
--
-------------------
-- SUBTYPES
-------------------
--
   SUBTYPE st_return_code IS VARCHAR2 (1);   -- define subtype for package return code string
   SUBTYPE st_return_msg IS VARCHAR2 (1000);   -- define subtype for package return code string
   SUBTYPE st_sql_string IS VARCHAR2 (4000);   -- define subtype for strings containing SQL statements
   SUBTYPE st_proc_name IS VARCHAR2 (30);   -- define subtype for strings containing procedure names
   SUBTYPE st_task_status IS VARCHAR2 (1000);   -- define subtype for strings containing task status
   SUBTYPE st_called_proc IS VARCHAR2 (256);   -- consistent type for procedure step tracking
--
-------------------
-- CONSTANTS
-------------------
--
   success_task_status   CONSTANT st_task_status := 'Success!';
--
-------------------
-- VARIABLES
-------------------
--
   gb_warning_flag                BOOLEAN        := FALSE;   -- flags warnings encountered
   gb_error_flag                  BOOLEAN        := FALSE;   -- flags errors encountered
   gb_stop_execution_flag         BOOLEAN        := FALSE;   -- flags stop of package execution
--
-------------------
-- EXCEPTIONS
-------------------
--
   ge_stop_execution              EXCEPTION;   --  global fatal error exception, stops processing
--
-------------------
-- FUNCTIONS
-------------------
--
-- Determine if warnings or errors were encountered
   FUNCTION fn_warnings_exist
      RETURN BOOLEAN;
   FUNCTION fn_errors_exist
      RETURN BOOLEAN;
--
-- Determine if execution should be stopped
   FUNCTION fn_stop_execution
      RETURN BOOLEAN;
--
-- Get standard values for return codes
   FUNCTION fn_return_code_ok
      RETURN st_return_code;
   FUNCTION fn_return_code_warning
      RETURN st_return_code;
   FUNCTION fn_return_code_error
      RETURN st_return_code;
--
--
-------------------
-- PROCEDURES
-------------------
--
-- Warning/error flag maintenance - ON/OFF settings
   PROCEDURE prc_set_warning_on;
   PROCEDURE prc_set_warning_off;
   PROCEDURE prc_set_error_on;
   PROCEDURE prc_set_error_off;
--
-- Standard package start procedure
   PROCEDURE prc_start_package (
      pv_application_name_in   IN   om_interface_logs.application_name%TYPE,
      pv_package_name_in       IN   om_interface_logs.package_name%TYPE,
      pv_ver_rel_num_in        IN   VARCHAR2,
      pv_ver_rel_date_in       IN   VARCHAR2,
      pv_procedure_name_in     IN   om_interface_logs.procedure_name%TYPE,
      pv_parameter_value_in    IN   om_interface_logs.parameter_value%TYPE DEFAULT NULL
   );
--
-- Normal end of package processing
   PROCEDURE prc_set_normal_end_of_package (
      pv_procedure_name_in   IN       om_interface_logs.procedure_name%TYPE,
      pv_return_code_out     OUT      st_return_code,
      pv_return_msg_out      OUT      st_return_msg
   );
--
-- Error end of package processing
   PROCEDURE prc_set_error_end_of_package (
      pv_procedure_name_in   IN       om_interface_logs.procedure_name%TYPE,
      pv_return_code_out     OUT      st_return_code,
      pv_return_msg_out      OUT      st_return_msg
   );
--
-- Truncate table procedure
   PROCEDURE prc_truncate_table (
      pv_owner_name_in   IN   all_tables.owner%TYPE,
      pv_table_name_in   IN   all_tables.table_name%TYPE
   );
-- Handle processing error
   PROCEDURE prc_handle_sql_error (
      pv_procedure_name_in   IN   om_interface_logs.procedure_name%TYPE,
      pv_log_text_in         IN   om_interface_logs.log_text%TYPE DEFAULT 'Unknown error',
      pb_log_error_in        IN   BOOLEAN DEFAULT TRUE,
      pb_stop_execution_in   IN   BOOLEAN DEFAULT TRUE
   );
--
-- Stop execution procedure
   PROCEDURE prc_stop_execution;
--
END om_log_batch_utl;
/