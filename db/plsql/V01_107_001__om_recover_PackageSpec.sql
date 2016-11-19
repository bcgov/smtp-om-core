
CREATE OR REPLACE PACKAGE OM.om_recover AS
-- $Header: v01_107_001__om_recover_packagespec  2016/Nov/10 1.0 jjose $
--*****************************************************************************
--*
--* Application: Custmom recovery module for Order Management
--* Program: om_recover PL/SQL Package
--*
--* 
--* Purpose: This package contains procedures for OM recoveries.
--*
--* Release  Date          Description
--* --------------------------------------------------------------------------
--* 1.0      2007-May-10   Bill Lupton - Package created.
--* 1.0 R1   2007-Jun-05   Bill Lupton - Release 1 - add ONE TIME recoveries.
--* 1.0 R1   2007-Jun-12   Bill Lupton - added pn_dflt_coding_flag.
--*                                    - added fn_is_bps_jv.
--*                                    - added prc_get_expense_coding.
--* 1.0 R1   2007-Jun-14   Bill Lupton - added fn_get_po_number.
--* 1.0 R2   2007-Jun-19   Bill Lupton - store recovery_id in log table key2_id.
--* 2.0 R0   2007-Jul-04   Bill Lupton - remove parameters from prc_get_expense_coding().
--* 3.0 R0   2008-Jan-04   Bill Lupton - change name of debug parameter to pn_validate_flag_in.
--*
--* 1.0 R0   2016-Nov-10   James Jose - Refactored the package for Order Management stream of SMTP project
--*****************************************************************************
--
--
--*************************
--* Function definitions
--*************************
--
--*************************
--* Procedure definitions
--*************************
--
   PROCEDURE prc_get_expense_coding (
      --pv_istore_org_in          IN              csi_item_instances.attribute12%TYPE,
      pn_dflt_coding_flag_in    IN              NUMBER,
      --pn_account_id_in          IN              NUMBER,
      pv_client_in_out          IN OUT          om_assets.expense_client%TYPE,           --csi_item_instances.attribute1%TYPE,
      pv_resp_in_out            IN OUT          om_assets.expense_responsibility%TYPE,           --csi_item_instances.attribute2%TYPE,
      pv_service_in_out         IN OUT          om_assets.expense_service_line%TYPE,           --csi_item_instances.attribute3%TYPE,
      pv_stob_in_out            IN OUT          om_assets.expense_stob%TYPE,           --csi_item_instances.attribute4%TYPE,
      pv_project_in_out         IN OUT          om_assets.expense_project%TYPE,           --csi_item_instances.attribute5%TYPE,
      pv_ccid_in_out            IN OUT          om_assets.expense_ccid%TYPE,           --csi_item_instances.attribute6%TYPE,
      pv_default_expense_flag   OUT NOCOPY      VARCHAR2,
      pv_return_code_out        OUT NOCOPY      VARCHAR2,
      pv_message_out            OUT NOCOPY      VARCHAR2);
   --
   PROCEDURE prc_process_recoveries (
      pv_recovery_type_in       IN              om_generic_table_details.key%TYPE,  --cas_generic_table_details.KEY%TYPE,
      pv_recovery_period_in     IN              om_fin_periods.period_name%TYPE, -- gl_periods.period_name%TYPE,
      pv_gl_period_in           IN              om_fin_periods.period_name%TYPE, --gl_periods.period_name%TYPE,
      pn_set_of_books_id_in     IN              om_fin_sets_of_books.set_of_books_id%TYPE, --gl_sets_of_books.set_of_books_id%TYPE,
      pn_run_id_out             OUT NOCOPY      om_interface_logs.run_id%TYPE, -- cas_interface_logs.run_id%TYPE,
      pv_return_code_out        OUT NOCOPY      VARCHAR2,
      pv_message_out            OUT NOCOPY      VARCHAR2,
      pn_dflt_coding_flag_in    IN              NUMBER DEFAULT 1,   -- use default coding?
      pn_trace_flag_in          IN              NUMBER DEFAULT 0,
      pn_validate_flag_in       IN              NUMBER DEFAULT 0,
      pv_customer_type_in       IN              VARCHAR2 DEFAULT NULL,
      pn_owner_party_id_in      IN              om_assets.owner_party_id%TYPE DEFAULT NULL, --csi_item_instances.owner_party_id%TYPE DEFAULT NULL,
      pn_seof_rk_in             IN              om_assets.SEOF_RK%TYPE DEFAULT NULL);--csi_item_instances.inventory_item_id%TYPE DEFAULT NULL);
--
--    PROCEDURE prc_expand_adjustment_periods (
--       pn_adjustment_id_in     IN              cas_ib_adjustments.adjustment_id%TYPE,
--       pn_set_of_books_id_in   IN              gl_sets_of_books.set_of_books_id%TYPE,
--       pv_return_code_out      OUT NOCOPY      VARCHAR2,
--       pv_message_out          OUT NOCOPY      VARCHAR2);
--
END om_recover;
/
