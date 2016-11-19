CREATE OR REPLACE PACKAGE BODY om.om_recover AS
   -- $Header: v01_108_001__om_recover_PackageBody 2016/11/17 1.0 James Jose $
   --***************************************************************************************************
   --*
   --* Application: CAS Install Base (Recoveries)
   --* Program: om_recoveries PL/SQL Package
   --*
   --* Title: Install Base recoveries
   --*
   --* Purpose: This package contains procedures for IB recoveries.
   --*
   --* Release  Date  Description
   --* --------------------------------------------------------------------------
   --* 1.0   2007-May-10 Bill Lupton - Package created.
   --* 1.0 R1  2007-Jun-05 Bill Lupton - Release 1 - add ONE TIME recoveries.
   --* 1.0 R1  2007-Jun-12 Bill Lupton - added pn_dflt_coding_flag.
   --*     - added fn_is_bps_jv.
   --*     - added prc_get_expense_coding.
   --* 1.0 R1  2007-Jun-14 Bill Lupton - added fn_get_po_number.
   --* 1.0 R2  2007-Jun-19 Bill Lupton - store recovery_id in log table key2_id.
   --*   2007-Jun-21 Bill Lupton - set recovery process flag to 'W' for WTS.
   --* 2.0 R0  2007-Jul-03 Bill Lupton - don't check for SDA account for non-ministry customers.
   --*     - don't flag failure to find SDA account as an error (warning only).
   --*   2007-Jul-04 Bill Lupton - remove parameters from prc_get_expense_coding() calls.
   --*     - change name of function from fn_is_bps_jv to fn_is_bps.
   --*     Modify function to only check for BPS type.
   --*     - round amounts to 2 decimal places.
   --* 3.0   2007-Jul-30 Bill Lupton - prc_process_other, prc_process_consumption - test for n_price=0 before writing zero price error message.
   --* 3.0   2007-Aug-09 Bill Lupton - prc_process_other, prc_process_consumption - save recovery stob and reset for each instance.
   --* 3.0   2007-Aug-14 Bill Lupton - fn_is_bps no longer used.  Check for customer_class = 'PUBLIC_SECTOR_INVOICED' to determine whether to change recovery stob.
   --* 4.0   2007-Aug-14 Bill Lupton - added prc_process_adjustments
   --*     - comment out fn_is_bps (Not used now. Recovery STOB is only changed for PUBLIC_SECTOR_INVOICED).
   --* 4.1   2007-Aug-14 Bill Lupton - prc_process_adjustments - don't update status when error occurs expanding period range.
   --* 5.0   2007-Oct-03 Bill Lupton - alert 162278 - modify recovery queries to use BPS instead of WTS to select BPS item instances
   --*     - maintain a count of dup key errors when inserting recoveries
   --* 5.0   2007-Oct-04 Bill Lupton - alert 162278 - modify adjustment recoveries to filter on customer type parameter
   --* 5.1   2008-Jan-03 Bill Lupton - alert 164938 - modify recovery code to allow prevalidation (pn_validate_flag_in flag).
   --*     - check customer class consistent with requested customer type.
   --* 6.0   2008-Jan-24 Bill Lupton - alert 165534 - validate given GL period name.
   --* 7.0   2008-Feb-24 Bill Lupton - alert 165950 - flag previous fiscal recoveries with 'F'.
   --* 8.0   2008-Apr-24 Bill Lupton - alert 167510 - recoveries missed for instances with back dated end dates
   --*     - alert 161619 - recovery credits.
   --* 8.1   2008-May-20 Bill Lupton - alert 169115 - validate recovery start/end dates.
   --* 8.2   2008-May-22 Bill Lupton - alert 161619 - fix bug in recovery_credit_status update.
   --* 9.0   2008-May-23 Bill Lupton - alert 164938 - validate cost centre party name begins with 'CC-'.
   --*   2008-Jun-05 Bill Lupton - alert 170422 - adjustment recoveries - trap errors to avoid abend.
   --* 10.0 2009-Mar-06 Bill Lupton - alert 178871 - monthly recoveries for multiple periods - use separate flag to track price errors for each period.
   --* 10.1 2009-Mar-10 Bill Lupton - character variable too small for version number.
   --* 11.0 2010-Feb-16 Wendm Sahle - New funding model changes based on attribute1 on cust name and colour.
   --* 12.0 2010-Aug-05 Sreedhar Doppalapudi - Added hint to the Credit program alert#191417
   --* 13.0  2010-Aug-26  Ketan Doshi - Modified the procedure prc_process_other, prc_process_consumption,prc_process_adjustments for Alert # 191418
   --* 14.0  2011-Sep-06  Bill Lupton - Alert 202659 - Modified procedure prc_process_other to process BPS recoveries for BC Ambulance Service
   --*                                - new function fn_isBPS() - return 1 if given party_id is BPS party
   --* 14.0  2012-Apr-27  Bill Lupton - Alert 202659 - implement BPS / BCAS recoveries for other recovery types.  BPS party_IDs are now
   --*                                  stored in CAS generic table CAS_BPS_PARTY_IDS.  This table must be configured for recoveries to run.
   --* 14.1  2012-Aug-21 Bill Lupton  - modify queries 
   --*                                   - use subqueries instead of calls to fn_selected_extended_attribute()
   --*                                   - remove use_hash hint, and parallel degree parameters
   --******************************************************************************************************************************************
   --
   -- Constants
   --
   gc_version_no   CONSTANT VARCHAR2(4) := '14.1';
   gc_version_dt   CONSTANT VARCHAR2(11) := '22-Aug-2012';
/*
   --
   --***************************************************************************************************
   --* Function : fn_get_recovery_flag
   --* Purpose : Determine if we need to recover or not for this customer and colour.
   --* Parameters: pn_account_id_in,
   --*  pv_account_number_in,
   --*  pv_account_name_in,
   --*  pv_colour_in
   --* Called By all procedures in this package.
   --***************************************************************************************************
  FUNCTION fn_get_recovery_flag(pn_account_id_in     IN hz_cust_accounts.cust_account_id%TYPE,
                                 pv_account_number_in IN hz_cust_accounts.account_number%TYPE,
                                 pv_account_name_in   IN hz_cust_accounts.account_name%TYPE,
                                 pv_colour_in         IN VARCHAR2)
      RETURN VARCHAR2 IS
      --
      v_do_not_recover   VARCHAR2(1);
      v_recovery_flag    VARCHAR2(1);
      v_recover_colour   VARCHAR2(1);
   --
   BEGIN
      -- Get attribute1 that tells us whether we need to recover or not.
      BEGIN
         SELECT NVL(ca.attribute1, 'Y')
           INTO v_recovery_flag
           FROM ar.hz_cust_accounts ca
          WHERE ca.cust_account_id = pn_account_id_in
            AND ca.account_number = pv_account_number_in
            AND ca.account_name = pv_account_name_in;
      EXCEPTION
         WHEN OTHERS THEN
            v_recovery_flag := 'Y';
      END;

      --
      IF v_recovery_flag = 'Y' THEN
         -- PLNET kind of customers will be recoved regardless of colour
         v_do_not_recover := 'I';
      ELSE
         -- See in cas generic table if this colour is excluded from recovery.
         BEGIN
            SELECT data1
              INTO v_recover_colour
              FROM cas_generic_table_details
             WHERE category = 'WTS_RECOVERY_COLOUR'
               AND key = pv_colour_in;
         EXCEPTION
            WHEN OTHERS THEN
               v_recover_colour := 'Y';
         END;

         --
         IF v_recover_colour = 'N' THEN
            -- ministry and colour is excluded from recovery
            -- and configured in cas_generic.
            v_do_not_recover := 'W';
         ELSE
            v_do_not_recover := 'I';
         END IF;
      END IF;

      --
      --
      RETURN v_do_not_recover;
   --
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END fn_get_recovery_flag;
*/
   --
   --***************************************************************************************************
   --* Function : fn_validate_period_name.
   --* Purpose : return true if given period name is valid for given period set.
   --* Called By prc_process_recoveries:
   --***************************************************************************************************
   FUNCTION fn_is_valid_period_name(pv_period_set_name_in IN om_fin_period_sets.period_set_name%TYPE,  --changed from gl_sets_of_books
                                    pv_period_in          IN om_fin_periods.period_name%TYPE)  --changed from gl_periods
      RETURN BOOLEAN IS
      --
      v_pd_name   om_fin_periods.period_name%TYPE;
   --
   BEGIN
      --
      /*SELECT period_name
        INTO v_pd_name
        FROM gl.gl_periods
       WHERE period_set_name = pv_period_set_name_in
         AND period_name = UPPER(pv_period_in)
         AND (period_name NOT LIKE 'ADJ2%'
          AND period_name NOT LIKE 'ADJ3%'
          AND period_name NOT LIKE 'ADJ4%');*/
          
      SELECT fipe.period_name
      INTO v_pd_name 
      FROM om_fin_period_sets fpse,
           om_fin_periods fipe         
      WHERE fpse.period_set_name = pv_period_set_name_in
      AND   fipe.period_name =  UPPER(pv_period_in)
      AND   fpse.fpse_rk = fipe.fpse_rk
      AND (fipe.period_name NOT LIKE 'ADJ2%'
      AND fipe.period_name NOT LIKE 'ADJ3%'
      AND fipe.period_name NOT LIKE 'ADJ4%');
      
      --
      RETURN TRUE;
   --
   EXCEPTION
      WHEN NO_DATA_FOUND THEN
         RETURN FALSE;
      WHEN OTHERS THEN
         RAISE;
   --
   END fn_is_valid_period_name;

   --
   --***************************************************************************************************
   --* Function : fn_get_po_number.
   --* Purpose : Get PO number for given item instance.
   --* Parameters: pn_request_number_in - item instance last_oe_order_line_id.
   --* Called By prc_process_other, prc_process_consumption:
   --***************************************************************************************************
   FUNCTION fn_get_po_number(pv_request_number_in IN NUMBER)
      RETURN VARCHAR2 IS
      --
      v_po_number  om_order_details.cust_po_number%TYPE; --oe_order_headers_all.cust_po_number%TYPE;
   --
   BEGIN
      --
      /*SELECT oh.cust_po_number
        INTO v_po_number
        FROM oe_order_lines_all ol,
             oe_order_headers_all oh
       WHERE ol.line_id = pn_line_id_in
         AND oh.header_id = ol.header_id;*/
      
       SELECT orde.cust_po_number
       INTO v_po_number
       FROM om_order_details orde
       WHERE orde.request_number = pv_request_number_in;
      --
      
      RETURN v_po_number;
   --
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END fn_get_po_number;

   --
   /*
   --***************************************************************************************************
   --* Function : fn_isBPS() - Alert 202659
   --* Purpose : Determine if the given party ID is a BPS party.
   --* Parameters: pn_party_id_in  - party ID
   --* Called By prc_process_other, prc_process_consumption:
   --***************************************************************************************************
   FUNCTION fn_isbps --(pn_party_id_in IN ar.hz_parties.party_id%TYPE)
      RETURN NUMBER IS
      --
      result   NUMBER := 0;
   --
   BEGIN
      -- query BPS party ID generic table for specified party_ID.
      BEGIN
         SELECT 1
           INTO result
           FROM casint.cas_generic_table_details
          WHERE category = 'CAS_BPS_PARTY_IDS'
            AND key = TO_CHAR(pn_party_id_in);
      EXCEPTION
         WHEN OTHERS THEN
            result := 0;
      END;

      RETURN result;
   END; --fn_isBPS()
*/
   --
   --***************************************************************************************************
   --* Function : fn_get_default_recovery_stob.
   --* Purpose : Get the default recovery stob for the given customer class.
   --* Parameters: pv_customer_type_in  - customer class code (e.g. PUBLIC_SECTOR_RECOVERIES).
   --* Called By prc_process_other, prc_process_consumption:
   --***************************************************************************************************
   FUNCTION fn_get_default_recovery_stob --(pv_customer_type_in IN hz_cust_accounts.customer_class_code%TYPE)
      RETURN VARCHAR2 IS
      --
      v_default_stob   VARCHAR2(4);
   --
   BEGIN
      --
      SELECT data4 default_stob
        INTO v_default_stob
        FROM om_generic_table_details
       WHERE category = 'WTS_CUST_CLASS_RECOVERY_TYPE';
        -- AND key = pv_customer_type_in;

      --
      RETURN v_default_stob;
   --
   EXCEPTION
      WHEN OTHERS THEN
         RETURN NULL;
   END fn_get_default_recovery_stob;
   /*
   --
   --***************************************************************************************************
   --* Procedure : prc_expand_adjustment_periods.
   --* Purpose : Get From/To period names from given cas_ib_adjustments record and expand the
   --*  period range into 1 record per period in cas_ib_adj_recoveries.
   --* Parameters: pn_adjustment_id_in  - key of adjustment record to expand.
   --*  pn_set_of_books_id  - used to determine period set name
   --* Called By : prc_process_adjustments:
   --***************************************************************************************************
   PROCEDURE prc_expand_adjustment_periods(pn_adjustment_id_in   IN            cas_ib_adjustments.adjustment_id%TYPE,
                                           pn_set_of_books_id_in IN            gl_sets_of_books.set_of_books_id%TYPE,
                                           pv_return_code_out       OUT NOCOPY VARCHAR2,
                                           pv_message_out           OUT NOCOPY VARCHAR2) IS
      --
      v_start_period              gl_periods.period_name%TYPE;
      v_end_period                gl_periods.period_name%TYPE;
      n_instance_id               csi.csi_item_instances.instance_id%TYPE;
      c_procedure_name   CONSTANT VARCHAR2(30) := 'prc_expand_adjustment_periods';

      --
      CURSOR cr_periods IS
         SELECT period_name
           FROM gl.gl_sets_of_books sob,
                gl.gl_periods pd
          WHERE sob.set_of_books_id = pn_set_of_books_id_in
            AND pd.period_set_name = sob.period_set_name
            AND pd.period_name NOT LIKE 'ADJ%'
            AND pd.start_date BETWEEN (SELECT start_date
                                         FROM gl.gl_periods pd2
                                        WHERE pd2.period_set_name = pd.period_set_name
                                          AND pd2.period_name = v_start_period)
                                  AND (SELECT start_date
                                         FROM gl.gl_periods pd2
                                        WHERE pd2.period_set_name = pd.period_set_name
                                          AND pd2.period_name = v_end_period)
         ORDER BY start_date;
   --
   BEGIN
      --
      pv_return_code_out := '0';

      --
      SELECT recovery_period_name_from, recovery_period_name_to, instance_id
        INTO v_start_period, v_end_period, n_instance_id
        FROM cas_ib_adjustments
       WHERE adjustment_id = pn_adjustment_id_in;

      --
      FOR r_period IN cr_periods LOOP
         BEGIN
            INSERT
              INTO cascsi.cas_ib_adj_recoveries(adj_recovery_id,
                                                adjustment_id,
                                                recovery_period_name,
                                                created_by,
                                                creation_date,
                                                last_updated_by,
                                                last_update_date)
            VALUES (cascsi_ib_adj_recoveries_s.NEXTVAL, pn_adjustment_id_in, r_period.period_name, cas_common_utl.fn_get_user_id('BATCH'),
                    SYSDATE, cas_common_utl.fn_get_user_id('BATCH'), SYSDATE);
         EXCEPTION
            WHEN DUP_VAL_ON_INDEX THEN
               -- ignore dup key (adjustment_id, period_name).
               -- This would only occur when restarting after an aborted run. -- V 9.0.
               cas_interface_log.prc_log_info(
                  c_procedure_name,
                  'dup key error ignored',
                     'instance_id='
                  || TO_CHAR(n_instance_id)
                  || ' adjustment_id='
                  || TO_CHAR(pn_adjustment_id_in)
                  || ' period='
                  || r_period.period_name
               );
         END;
      END LOOP;
   --
   EXCEPTION
      WHEN OTHERS THEN
         pv_return_code_out := '2';
         pv_message_out :=    'prc_expand_adjustment_periods('
                           || TO_CHAR(pn_adjustment_id_in)
                           || ', '
                           || TO_CHAR(pn_set_of_books_id_in)
                           || '): '
                           || SQLERRM;
   --
   END prc_expand_adjustment_periods;
*/
   --
   --***************************************************************************************************
   --* Procedure : prc_get_expense_coding
   --* Purpose : Get expense GL coding.  If required, look up default coding.
   --* Parameters: pv_istore_org_in   - iStore Org (attribute12 - e.g. TH).
   --*  pn_dflt_coding_flag_in  - use default GL coding if given coding is invalid.
   --*  pv_client_in_out
   --*  pv_resp_in_out
   --*  pv_service_in_out
   --*  pv_stob_in_out
   --*  pv_project_in_out
   --*  pv_ccid_in_out
   --*  pv_return_code_out  - procedure return code ('0'=ok, '1'=warning, '2'=error).
   --*  pv_message_out   - optional output message.
   --* Called By prc_process_other, prc_process_consumption:
   --***************************************************************************************************  
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
      pv_message_out            OUT NOCOPY      VARCHAR2)
      IS
      v_message   VARCHAR2(4000);
      
      --
   BEGIN
      --
      pv_return_code_out := '0';
      pv_default_expense_flag := 'N';

      --
     
      --
      -- If ccid is null and default coding flag is set, check for default coding.
      -- Otherwise, just return input code values.
      --
      IF (pv_ccid_in_out IS NULL
      AND pn_dflt_coding_flag_in = 1) THEN
         --
         /*IF (pn_account_id_in IS NULL) THEN
            -- can't find default coding without TCA account ID.
            pv_return_code_out := '1';
            pv_message_out := 'Cannot look up default GL coding because TCA account ID is null.';*/
        /* ELSIF (pv_istore_org_in IS NULL) THEN
            -- can't validate default coding without iStore org.
            pv_return_code_out := '1';
            pv_message_out := 'Cannot validate default GL coding because iStore org is null.';*/
         --ELSE
            om_utl.prc_get_default_gl_coding(--pn_account_id_in,
                                                 pv_client_in_out,
                                                 pv_resp_in_out,
                                                 pv_service_in_out,
                                                 pv_project_in_out,
                                                 pv_return_code_out,
                                                 v_message);

            --
            IF (pv_return_code_out > '0') THEN
               pv_message_out := 'Failed to find default GL coding: ' || v_message;
            ELSE
               -- validate default coding.
               pv_default_expense_flag := 'Y';
               /*pv_ccid_in_out := cas_om_utl.fn_get_ccid(pv_client_in_out,
                                                        pv_resp_in_out,
                                                        pv_service_in_out,
                                                        pv_stob_in_out,
                                                        pv_project_in_out,
                                                        pv_istore_org_in);*/
                                                       
                --Temporary workaround
                pv_ccid_in_out := '12345';

               IF (pv_ccid_in_out IS NULL) THEN
                  pv_return_code_out := '1';
                  pv_message_out := 'Default GL coding is invalid.';
               END IF;
            --
            END IF;
         --END IF;
      END IF; -- ccid is null.
   --
   --
   EXCEPTION
      WHEN OTHERS THEN
         pv_return_code_out := '2';
         pv_message_out := 'prc_get_expense_coding(): ' || SQLERRM;
   END prc_get_expense_coding;

   --
   --***************************************************************************************************
   --* Procedure : prc_process_other
   --* Purpose : Process recoveries for shared corporate functions in given recovery fiscal period.
   --*  If the item instance has RECOVERY_STARTED=NO then recovery transactions will be
   --*  generated for all outstanding periods. (i.e. from item_instance.recovery_start_date
   --*  until end of given recovery period.
   --* Parameters: pv_recovery_type_in  - type of recovery (i.e. COMMON).
   --*  pv_recovery_period_in - period for which recoveries are generated (e.g. APR-08).
   --*  pv_gl_period_in   - GL period to which recoveries are posted (e.g. MAY-08).
   --*  pn_set_of_books_id_in - set of books id (e.g. 16=BCGOV).
   --*  pn_run_id_out   - run id - generated by cas_interface_log package.
   --*  pv_return_code_out  - procedure return code ('0'=ok, '1'=warning, '2'=error).
   --*  pv_message_out   - optional output message.
   --*  pn_dflt_coding_flag_in  - optional input flag to use default coding if given coding is invalid.
   --*  pn_trace_flag_in  - optional input flag to enable tracing to cas_interface_logs.
   --*  pn_validate_flag_in   - optional flag to run validation checks only.
   --*  pv_customer_type_in   - optional customer type  (M=Ministry, B=BPS, null=both).
   --*  pn_owner_party_id_in   - optional owner_party_id to limit rows for testing.
   --*  pn_seof_rk_in  - optional pn_seof_rk_in to limit rows for testing.
   --* Called By :
   --***************************************************************************************************

   PROCEDURE prc_process_other(
      pv_recovery_type_in     IN            om_generic_table_details.key%TYPE,
      pv_recovery_period_in   IN            om_fin_periods.period_name%TYPE,
      pv_gl_period_in         IN            om_fin_periods.period_name%TYPE,
      pn_set_of_books_id_in   IN            om_fin_sets_of_books.set_of_books_id%TYPE,
      pn_run_id_out              OUT NOCOPY om_interface_logs.run_id%TYPE,
      pv_return_code_out         OUT NOCOPY VARCHAR2,
      pv_message_out             OUT NOCOPY VARCHAR2,
      pn_dflt_coding_flag_in  IN            NUMBER DEFAULT 1,
      -- use default coding?
      pn_trace_flag_in        IN            NUMBER DEFAULT 0,
      pn_validate_flag_in     IN            NUMBER DEFAULT 0,
      pv_customer_type_in     IN            VARCHAR2 DEFAULT NULL,
      pn_owner_party_id_in    IN            om_assets.owner_party_id%TYPE DEFAULT NULL,
      pn_seof_rk_in IN            om_assets.seof_rk%TYPE DEFAULT NULL
   ) IS
      --
      -- define constant for procedure name; used in calls to CAS_INTERFACE_LOG package.
      c_procedure_name      CONSTANT VARCHAR2(30) := 'prc_process_other';
      --
      -- cursor to select item instances to generate recovery transactions.
      --
      -- Alert # 191418
      n_om_recovery_start_flag_id   NUMBER;
      n_om_bps_cost_centre_id       NUMBER;
      n_om_recovery_start_date      NUMBER;
      n_om_recovery_end_date        NUMBER;
      n_om_system_recovery_method   NUMBER;

      -- Alert 202659 - BCAS recoveries - wts party id parameter no longer required

      CURSOR cr_ib_recoveries(cv_period_start_date  IN VARCHAR2,
                              cv_period_end_date    IN VARCHAR2,
                              cv_recovery_frequency IN VARCHAR2,
                              cv_recovery_method    IN VARCHAR2) IS
         SELECT inst.*
           FROM (SELECT /*+ parallel (item_instance) parallel (sr) */
                       item_instance.aset_rk,
                        item_instance.asset_reference,
                        --item_instance.object_version_number,
                        item_instance.seof_rk,
                        --item_instance.inv_master_organization_id,
                        --item_instance.last_vld_organization_id,
                        item_instance.asset_tag,
                        item_instance.orde_rk,
                        seof.display_name,
                        --                        NVL(cas_ib_utl.fn_select_extended_attribute( item_instance.instance_id, n_cas_recovery_start_flag_id), 'NO') recovery_started, -- Alert # 191418
                        --                        cas_ib_utl.fn_select_extended_attribute( item_instance.instance_id, n_cas_bps_cost_centre_id) bps_cost_centre,
                        --                        cas_ib_utl.fn_select_extended_attribute( item_instance.instance_id, n_cas_recovery_start_date) recovery_start_date,
                        --                        cas_ib_utl.fn_select_extended_attribute( item_instance.instance_id, n_cas_recovery_end_date) recovery_end_date,
                        --                        cas_ib_utl.fn_select_extended_attribute( item_instance.instance_id, n_cas_system_recovery_method) system_recovery_method,
                        (SELECT NVL(MAX(asset_param_value), 'NO')
                           FROM om.om_arp_values
                          WHERE aset_rk = item_instance.aset_rk
                            AND arpa_rk = n_om_recovery_start_flag_id)
                           recovery_started,
                        (SELECT MAX(asset_param_value)
                           FROM om.om_arp_values
                          WHERE aset_rk = item_instance.aset_rk
                            AND arpa_rk = n_om_bps_cost_centre_id)
                           bps_cost_centre,
                        (SELECT MAX(asset_param_value)
                           FROM om.om_arp_values
                          WHERE aset_rk = item_instance.aset_rk
                            AND arpa_rk = n_om_recovery_start_date)
                           recovery_start_date,
                        (SELECT MAX(asset_param_value)
                           FROM om.om_arp_values
                          WHERE aset_rk = item_instance.aset_rk
                            AND arpa_rk = n_om_recovery_end_date)
                           recovery_end_date,
                        (SELECT MAX(asset_param_value)
                           FROM om.om_arp_values
                          WHERE aset_rk = item_instance.aset_rk
                            AND arpa_rk = n_om_system_recovery_method)
                           system_recovery_method,
                        item_instance.quantity,
                        item_instance.unit_of_measure,
                        item_instance.expense_client,
                        item_instance.expense_responsibility,
                        item_instance.expense_service_line,
                        item_instance.expense_stob,
                        item_instance.expense_project,
                        item_instance.expense_ccid,
                        --item_instance.owner_party_id,
                        --item_instance.owner_party_account_id,
                        item_instance.description,
                        --item_instance.attribute10 istore_org,
                        item_instance.recovery_frequency,
                        NVL(item_instance.order_price, '0') order_price,
                        sr.service_receipt_status
                   FROM om_assets item_instance,
                        om_service_reciept sr,
                        om_service_offerings seof
                  WHERE item_instance.recovery_frequency = cv_recovery_frequency
                    AND ((pv_customer_type_in = 'B'
                      AND item_instance.owner_party_id IN (SELECT key
                                                             FROM om.om_generic_table_details
                                                            WHERE category = 'CAS_BPS_PARTY_IDS'))
                      OR (pv_customer_type_in = 'M'
                      AND item_instance.owner_party_id NOT IN (SELECT key
                                                                 FROM om.om_generic_table_details
                                                                WHERE category = 'CAS_BPS_PARTY_IDS'))
                      OR pv_customer_type_in IS NULL)
                    AND (item_instance.owner_party_id = pn_owner_party_id_in
                      OR pn_owner_party_id_in IS NULL)
                    AND (item_instance.seof_rk = pn_seof_rk_in
                      OR pn_seof_rk_in IS NULL)
                    AND sr.aset_rk = item_instance.aset_rk
                    AND sr.service_receipt_status IN ('RECEIVED', 'NOT REQUIRED', 'DEEMED RECEIVED')
                    and item_instance.seof_rk = seof.seof_rk ) inst
          WHERE inst.system_recovery_method = cv_recovery_method
            AND inst.recovery_start_date < cv_period_end_date
            AND (inst.recovery_end_date >= cv_period_start_date
              OR inst.recovery_end_date IS NULL
              OR inst.recovery_started = 'NO' -- V 8.0.
                                             -- don't skip instances with non-null end date that precedes current recovery period.
                )
            AND (pv_recovery_type_in = 'ONE TIME'
             AND inst.recovery_started = 'NO'
              OR pv_recovery_type_in != 'ONE TIME')
         ORDER BY seof_rk;

      --
      -- Cursor to select periods for recovery transactions.
      --
      -- NOTE: For ONE TIME recoveries (cv_recovery_frequency='ONE'),
      --     only one period will be processed (the period specified
      --     by the instance recovery dates).
      --     For other types (COMMON, MONTHLY) multiple periods
      --     are selected if recovery_started=NO.
      --
      CURSOR cr_recovery_periods(
         cv_period_set_name            IN VARCHAR2,
         cv_recovery_frequency         IN VARCHAR2,
         cv_recovery_started           IN VARCHAR2,
         cd_recovery_period_start_date IN DATE,
         cd_instance_period_start_date IN DATE,
         cd_instance_end_date          IN DATE
      -- V 8.0.
      -- new parameter to support CASE statement below.
      ) IS
         SELECT period_name, period_year
           FROM om_fin_periods fipe,
                om_fin_period_sets fpse
          WHERE fpse.period_set_name = cv_period_set_name
            and fpse.fpse_rk = fipe.fpse_rk
            AND fipe.start_date >= TO_DATE( '01-APR-2007', 'dd-mon-yyyy')
            AND fipe.start_date <=
                   CASE
                      -- V 8.0.  - avoid recovering beyond instance end date.
                      WHEN (cv_recovery_frequency = 'ONE') THEN
                         cd_instance_period_start_date
                      ELSE
                         CASE
                            WHEN (cv_recovery_started = 'YES') THEN
                               cd_recovery_period_start_date
                            ELSE -- don't recover beyond instance end date.
                               NVL(LEAST( cd_instance_end_date, cd_recovery_period_start_date),
                                   cd_recovery_period_start_date)
                         END
                   END
            AND fipe.start_date >=
                   CASE
                      WHEN (cv_recovery_started = 'NO') THEN cd_instance_period_start_date
                      ELSE cd_recovery_period_start_date
                   END
            AND fipe.period_name NOT LIKE 'ADJ%';

      --
      v_period_set_name              om_fin_period_sets.period_set_name%TYPE;
      d_recovery_period_start_date   om_fin_periods.start_date%TYPE;
      d_recovery_period_end_date     om_fin_periods.end_date%TYPE;
      n_recovery_period_year         om_fin_periods.period_year%TYPE;
      d_instance_period_start_date   om_fin_periods.start_date%TYPE;
      d_instance_period_end_date     om_fin_periods.end_date%TYPE;
      n_instance_period_year         om_fin_periods.period_year%TYPE;
      n_prev_seof_rk       om_service_offerings.seof_rk%TYPE := 0;
      v_item_name                    om_service_offerings.display_name%TYPE;
      v_unit_of_measure                     om_service_offerings.unit_of_measure%TYPE;
      n_order_price                        NUMBER;
      n_run_id                       om_interface_logs.run_id%TYPE;
      n_reco_rk                  om_recoveries.reco_rk%TYPE := 0;
      v_recovery_method              om_generic_table_details.data1%TYPE;
      v_recovery_frequency           om_generic_table_details.data2%TYPE;
      v_cust_class_cust_type         om_generic_table_details.data1%TYPE;
      v_cust_class_recovery_method   om_generic_table_details.data2%TYPE;
      v_recovery_price_source        om_service_parameters.parameter_value%TYPE;
      v_colour                       om_service_parameters.parameter_value%TYPE;
      v_recovery_client              om_assets.expense_client%TYPE;
      v_recovery_resp                om_assets.expense_responsibility%TYPE;
      v_recovery_service             om_assets.expense_service_line%TYPE;
      v_recovery_stob                om_assets.expense_stob%TYPE;
      v_save_stob                    om_assets.expense_stob%TYPE;
      v_recovery_project             om_assets.expense_project%TYPE;
      --
      v_expense_client               om_assets.expense_client%TYPE;
      v_expense_resp                 om_assets.expense_responsibility%TYPE;
      v_expense_service              om_assets.expense_service_line%TYPE;
      v_expense_stob                 om_assets.expense_stob%TYPE;
      v_expense_project              om_assets.expense_project%TYPE;
      v_expense_ccid                 om_assets.expense_ccid%TYPE;
      v_po_number                    om_order_details.cust_po_number%TYPE;
      v_default_expense_flag         VARCHAR2(1);
      v_return_code                  VARCHAR2(1);
      v_message                      VARCHAR2(4000);
      --v_cost_centre_party_name       hz_parties.party_name%TYPE;
      --v_customer_class_code          hz_cust_accounts.customer_class_code%TYPE;
      --n_account_id                   hz_cust_accounts.cust_account_id%TYPE;
      --n_sda_account_id               hz_cust_accounts.cust_account_id%TYPE;
      --v_account_number               hz_cust_accounts.account_number%TYPE;
      --v_account_name                 hz_cust_accounts.account_name%TYPE;
      --v_ministry_code                hz_cust_accounts.account_name%TYPE;
      -- WENDM - Feb 15 new fundiing model.START
      v_recovery_flag                VARCHAR2(1); -- Recover Y or N
      -- WENDM - Feb 15 new fundiing model.END
      --n_party_id                     hz_cust_accounts.party_id%TYPE;
      --n_sda_party_id                 hz_cust_accounts.party_id%TYPE;
      --n_bill_to_address              csi_ip_accounts.bill_to_address%TYPE;
      -- Alert 202659 - n_wts_party_id no longer required
      --  n_wts_party_id                        hz_parties.party_id%TYPE;
      --
      -- numeric return code required for CAS_OM_UTL.
      n_return_code                  NUMBER;
      --t_attributes_tbl               om_utl.tt_ib_update_tbl;
      --
      -- The flags below indicate error conditions with item or item_instance that
      -- would prevent the recovery transaction from being processed successfully.
      -- Used when setting the transaction process_flag column.
      --
      v_error_flag                   VARCHAR2(1); -- error (Y/N).
      v_price_error_flag             VARCHAR2(1); -- price error (Y/N). V 10.0 - BL - Mar 6/09.
      v_recovery_insert_error        VARCHAR2(1);
      v_recovery_date_error          VARCHAR2(1);
      -- problem inserting recovery record (Y/N).
      n_error_count                  NUMBER := 0;
      -- number of records with a problem
      n_total_count                  NUMBER := 0;
      -- total number of consumption records processed
      n_existing_recovery_count      NUMBER := 0;
      -- total number of recovery records skipped because a recovery record already exists
      v_process_flag                 om.om_recoveries.process_flag%TYPE;
      v_period_found                 VARCHAR2(1);
   -- (Y/N) at least one period found for the current instance.
   --
   ---
   BEGIN
      --
      -- Alert # 191418
      n_om_recovery_start_flag_id := OM_utl.fn_get_arpa_rk('CAS_RECOVERY_START_FLAG');
      n_om_bps_cost_centre_id := OM_utl.fn_get_arpa_rk('CAS_BPS_COST_CENTRE');
      n_om_recovery_start_date := OM_utl.fn_get_arpa_rk('CAS_RECOVERY_START_DATE');
      n_om_recovery_end_date := OM_utl.fn_get_arpa_rk('CAS_RECOVERY_END_DATE');
      n_om_system_recovery_method := OM_utl.fn_get_arpa_rk('CAS_SYSTEM_RECOVERY_METHOD');


      -- log start of recovery run
      --
      om_log_batch_utl.prc_start_package(
         'OM Recoveries',
         'OM_RECOVER',
         gc_version_no,
         gc_version_dt,
         c_procedure_name,
            ' recovery type='
         || pv_recovery_type_in
         || ' recovery_period='
         || pv_recovery_period_in
         || ' gl_period='
         || pv_gl_period_in
         || ' set_of_books_id='
         || pn_set_of_books_id_in
         || ' trace='
         || pn_trace_flag_in
         || ' validate='
         || pn_validate_flag_in
         || ' customer_type='
         || pv_customer_type_in
         || ' owner_party_id='
         || pn_owner_party_id_in
         || ' seof_rk='
         || pn_seof_rk_in
      );
      --
      -- get current run_id (entered on each IB_recovery row).
      --
      n_run_id := om_interface_log.fn_run_id;
      pn_run_id_out := n_run_id;

      -- Alert 202659 - BCAS recoveries - move check for BPS party table to main procedure
      --
      -- get recovery type info (i.e. recovery method and frequency).
      --
      OM_utl.prc_select_recovery_type(pv_recovery_type_in,
                                          v_recovery_method,
                                          v_recovery_frequency,
                                          v_return_code,
                                          v_message);

      --
      IF (v_return_code > 0) THEN
         raise_application_error( -20000, 'Error retrieving recovery method and frequency for recovery type ' || pv_recovery_type_in || ': ' || v_message);
      END IF;

      --
      -- get info re: set of books
      --
      OM_utl.prc_select_set_of_books(pn_set_of_books_id_in,
                                         v_period_set_name,
                                         v_return_code,
                                         v_message);

      --
      IF (v_return_code > 0) THEN
         raise_application_error( -20000, 'Error retrieving set of books info for id=' || pn_set_of_books_id_in || ': ' || v_message);
      END IF;

      --
      -- validate GL period name.
      --
      IF (NOT fn_is_valid_period_name( v_period_set_name, pv_gl_period_in)) THEN
         raise_application_error( -20000, 'Invalid GL period name: ' || pv_gl_period_in);
      END IF;

      --
      -- get recovery period start/end dates
      --
      OM_utl.prc_get_gl_period_dates(v_period_set_name,
                                         UPPER(pv_recovery_period_in),
                                         d_recovery_period_start_date,
                                         d_recovery_period_end_date,
                                         n_recovery_period_year,
                                         v_return_code,
                                         v_message);

      --
      IF (v_return_code > 0) THEN
         raise_application_error( -20000, 'Error retrieving period start/end dates for recovery period ' || pv_recovery_period_in || ': ' || v_message);
      END IF;

      --
      IF (pn_trace_flag_in = 1) THEN
         om_interface_log.prc_log_trace(
            c_procedure_name,
            'TRACE: executing cursor cr_ib_recoveries',
               'Period='
            || pv_recovery_period_in
            || ' period_start_date='
            || TO_CHAR( d_recovery_period_start_date, 'YYYY/MM/DD')
            || ' period_end_date='
            || TO_CHAR( d_recovery_period_end_date, 'YYYY/MM/DD')
            || ' method='
            || v_recovery_method
            || ' frequency='
            || v_recovery_frequency
         );
      END IF;

     --
     -- Loop through item instances to process recoveries.
     --
     <<instance_loop>>
      FOR r_recovery IN cr_ib_recoveries(TO_CHAR( d_recovery_period_start_date, 'YYYY/MM/DD'),
                                         TO_CHAR( d_recovery_period_end_date, 'YYYY/MM/DD'),
                                         v_recovery_frequency,
                                         v_recovery_method --                          cas_ib_utl.fn_get_party_id ('BPS')
                                                          ) LOOP
         --
         n_total_count := n_total_count + 1;
         --
         v_error_flag := 'N'; -- initialize error flag.
         v_recovery_insert_error := 'N'; -- init insert error flag.
         v_recovery_date_error := 'N'; -- init date error flag.  V 8.1.

         --
         BEGIN
            -- V 8.1.
            -- log invalid recovery start date
            --
            -- check for start date prior to beginning of fiscal 2008.
            --
            IF (TO_DATE( r_recovery.recovery_start_date, 'yyyy/mm/dd hh24:mi:ss') < TO_DATE( '01-APR-2007', 'dd-mon-yyyy')) THEN
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Recovery start date before beginning of fiscal 2008: ' || r_recovery.recovery_start_date,
                  'aset_rk=' || r_recovery.aset_rk,
                  r_recovery.aset_rk
               );
               v_error_flag := 'Y';
               v_recovery_date_error := 'Y';
               n_error_count := n_error_count + 1;
            END IF;

            --
            -- check for start date not equal to first day of month.
            --
            IF (SUBSTR(r_recovery.recovery_start_date,
                       9,
                       2) <> '01') THEN
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Recovery start date not first day of month: ' || r_recovery.recovery_start_date,
                  'aset_rk=' || r_recovery.aset_rk,
                  r_recovery.aset_rk
               );
               v_error_flag := 'Y';
               v_recovery_date_error := 'Y';
               n_error_count := n_error_count + 1;
            END IF;
         --
         EXCEPTION
            WHEN OTHERS THEN
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Error when validating recovery start date ' || r_recovery.recovery_start_date || ': ' || SQLERRM,
                  'aset_rk=' || r_recovery.aset_rk,
                  r_recovery.aset_rk
               );
               v_error_flag := 'Y';
               v_recovery_date_error := 'Y';
               n_error_count := n_error_count + 1;
         END;

         --
         BEGIN
            -- log invalid recovery end date
            --
            -- check for end date not equal to last day of month.  (Non-fatal error).
            --
            IF (TO_DATE( r_recovery.recovery_end_date, 'yyyy/mm/dd hh24:mi:ss') <>
                   LAST_DAY(TO_DATE( r_recovery.recovery_end_date, 'yyyy/mm/dd hh24:mi:ss'))) THEN
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Recovery end date not last day of month: ' || r_recovery.recovery_end_date,
                  'aset_rk=' || r_recovery.aset_rk,
                  r_recovery.aset_rk
               );
            --         v_error_flag := 'Y';
            --         v_recovery_date_error := 'Y';
            --         n_error_count := n_error_count + 1;
            END IF;
         --
         EXCEPTION
            WHEN OTHERS THEN
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Error when validating recovery end date ' || r_recovery.recovery_end_date || ': ' || SQLERRM,
                  'aset_rk=' || r_recovery.aset_rk,
                  r_recovery.aset_rk
               );
               v_error_flag := 'Y';
               v_recovery_date_error := 'Y';
               n_error_count := n_error_count + 1;
         END;

         -- V 9.0.
         -- validate BPS Cost Centre party name begins with 'CC-'.
         --
        /* IF (r_recovery.bps_cost_centre IS NOT NULL) THEN
            --
            BEGIN
               SELECT party_name
                 INTO v_cost_centre_party_name
                 FROM ar.hz_parties
                WHERE party_id = r_recovery.bps_cost_centre;

               --
               IF (SUBSTR(v_cost_centre_party_name,
                          1,
                          3) <> 'CC-') THEN
                  om_log_batch_utl.prc_set_warning_on;
                  om_interface_log.prc_log_warning(
                     c_procedure_name,
                     'BPS cost centre party name does not begin with CC-: ' || v_cost_centre_party_name,
                     'aset_rk=' || r_recovery.aset_rk || ' bps_cost_centre=' || r_recovery.bps_cost_centre,
                     r_recovery.aset_rk
                  );
                  v_error_flag := 'Y';
                  n_error_count := n_error_count + 1;
               END IF;
            EXCEPTION
               WHEN OTHERS THEN
                  om_log_batch_utl.prc_set_warning_on;
                  om_interface_log.prc_log_warning(
                     c_procedure_name,
                     'Error when validating BPS cost centre: ' || r_recovery.bps_cost_centre || ': ' || SQLERRM,
                     'aset_rk=' || r_recovery.aset_rk,
                     r_recovery.aset_rk
                  );
                  v_error_flag := 'Y';
                  n_error_count := n_error_count + 1;
            END;
         END IF; -- bps_cost_centre is not null.
*/
         --
         -- When seof_rk changes, get item name, recovery source and recovery coding.
         --
         IF (r_recovery.seof_rk != n_prev_seof_rk) THEN
            --
            -- get name of current item
            --
            SELECT display_name item_name, unit_of_measure
              INTO v_item_name, v_unit_of_measure
              FROM om_service_offerings
             WHERE seof_rk = r_recovery.seof_rk;
              -- AND organization_id = r_recovery.inv_master_organization_id;

            --
            -- get recovery price source for current item (i.e. ITEM or ORDER).
            --
            v_recovery_price_source := OM_utl.fn_select_catalog_element( r_recovery.seof_rk, 'Recovery Price Source');

            --
            IF (v_recovery_price_source IS NULL) THEN
               -- log missing recovery price source
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(c_procedure_name,
                                                 'Item recovery price source is missing or blank; defaulted to ITEM ',
                                                 'seof_rk=' || r_recovery.seof_rk,
                                                 r_recovery.aset_rk);
            --
            END IF;

            --
            v_colour := OM_utl.fn_select_catalog_element( r_recovery.seof_rk, 'Colour');

            --
            IF (v_colour IS NULL) THEN
               -- log missing colour
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(c_procedure_name,
                                                 'Item colour is missing or blank.',
                                                 'seof_rk=' || r_recovery.seof_rk,
                                                 r_recovery.aset_rk);
            --
            END IF;

            --
            IF (pn_trace_flag_in = 1) THEN
               om_interface_log.prc_log_trace( c_procedure_name, 'TRACE: Processing seof_rk=' || r_recovery.seof_rk || ' (' || v_item_name || ') Recovery Price Source=' || v_recovery_price_source || ' Colour=' || v_colour);
            END IF;

            --
            -- get recovery GL coding for current item
            --
            OM_utl.prc_select_recovery_coding(r_recovery.seof_rk,
                                                  v_recovery_client,
                                                  v_recovery_resp,
                                                  v_recovery_service,
                                                  v_recovery_stob,
                                                  v_recovery_project,
                                                  v_return_code,
                                                  v_message);
            --
            -- save stob - may need to reset v_recovery_stob if it's changed for a BPS invoice recovery.
            v_save_stob := v_recovery_stob;

            --
            IF (v_return_code > 0
             OR v_recovery_client IS NULL
             OR v_recovery_resp IS NULL
             OR v_recovery_service IS NULL
             OR v_recovery_stob IS NULL
             OR v_recovery_project IS NULL) THEN
               -- log recovery coding error.
               om_interface_log.prc_log_warning(c_procedure_name,
                                                 'Recovery coding error: ' || v_message,
                                                 'seof_rk=' || r_recovery.seof_rk,
                                                 r_recovery.aset_rk);
               om_log_batch_utl.prc_set_warning_on;
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
            --
            END IF;

            --
            IF (pn_trace_flag_in = 1) THEN
               om_interface_log.prc_log_trace(
                  c_procedure_name,
                     'TRACE: recovery coding='
                  || v_recovery_client
                  || '.'
                  || v_recovery_resp
                  || '.'
                  || v_recovery_service
                  || '.'
                  || v_recovery_stob
                  || '.'
                  || v_recovery_project,
                  r_recovery.seof_rk
               );
            --
            END IF;

            --
            n_prev_seof_rk := r_recovery.seof_rk;
         --
         ELSE
            -- reset recovery stob in case it's been changed for a BPS invoice recovery.
            v_recovery_stob := v_save_stob;
         --
         END IF; -- new seof_rk.

         --
         -- get customer info (TCA account and party).
         --
        /* OM_utl.prc_select_customer_info(r_recovery.aset_rk,
                                             v_customer_class_code,
                                             n_account_id,
                                             v_account_number,
                                             v_account_name,
                                             n_party_id,
                                             n_bill_to_address,
                                             v_return_code,
                                             v_message);

         --
         */
         IF (v_return_code > 0) THEN
            -- log failure to retrieve customer info.
            om_log_batch_utl.prc_set_warning_on;
            om_interface_log.prc_log_warning(
               c_procedure_name,
               'Failed to retrieve customer class and/or TCA account/party info: ' || v_message,
                  'aset_rk= '
               || r_recovery.aset_rk
               || /*' TCA Account ID='
               || TO_CHAR(n_account_id)
               || ' customer class='
               || v_customer_class_code,*/
               r_recovery.aset_rk
            );
            --
            v_error_flag := 'Y';
            n_error_count := n_error_count + 1;
            --
            --v_ministry_code := '';
         --
        /* ELSE
            -- check customer class consistent with customer type input parameter.
            -- Alert 202659 - BCAS recoveries
           IF (fn_isbps(r_recovery.owner_party_id) = 1
            AND v_customer_class_code NOT LIKE 'PUBLIC_SECTOR%'
             OR fn_isbps(r_recovery.owner_party_id) = 0
            AND v_customer_class_code NOT LIKE 'MINISTRY%') THEN
               -- log inconsistency between owner_party and cust_class.
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(
                  c_procedure_name,
                     'Owner party_id '
                  || r_recovery.owner_party_id
                  || ' is inconsistent with customer class '
                  || v_customer_class_code,
                  'aset_rk= ' || r_recovery.aset_rk || ' TCA Account ID=' || TO_CHAR(n_account_id),
                  r_recovery.aset_rk
               );
               --
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
            --
            END IF;*/

            -- parse ministry code from TCA name. Get the string between the two dashes.
            -- This is used to check for 'WTS' when setting the recovery process flag.
           /* v_ministry_code := SUBSTR(v_account_name,
                                      5,
                                      INSTR(v_account_name,
                                      '-',
                                      5) - 5);

            ---------------------------------------------------------------------------------------------
            -- WENDM get recovery flag using cust_account_id, cust_account_number and cust_account name
            -- returned from the above lookup. Return upper case Y or N.
            -- Colour BLUE is hardcoded for now but can be putin cas_generci tables.
            -- All records with PROCESS_FLAG of W in om_recoveries will be ignored by recovery JV process.
            IF v_ministry_code = 'WTS' THEN
               v_recovery_flag := 'W';
            ELSIF (SUBSTR(v_customer_class_code,
                          1,
                          8) = 'MINISTRY') THEN
               v_recovery_flag := fn_get_recovery_flag(n_account_id,
                                                       v_account_number,
                                                       v_account_name,
                                                       v_colour);
            ELSE
               v_recovery_flag := 'I';
            END IF;

            --
            --
            IF (SUBSTR(v_customer_class_code,
                       1,
                       8) != 'MINISTRY') THEN
               -- default SDA account ID to owner_party account ID for non-ministry customers.
               n_sda_account_id := r_recovery.owner_party_account_id;
               n_sda_party_id := r_recovery.owner_party_id;

               --
               -- check for BPS customer type and replace recovery stob if necessary.
               --          IF (fn_is_bps (v_customer_class_code) ) THEN
               IF (v_customer_class_code = 'PUBLIC_SECTOR_INVOICED') THEN
                  OM_utl.prc_get_bps_recoveries_stob(r_recovery.aset_rk,
                                                         v_recovery_stob,
                                                         v_return_code,
                                                         v_message);

                  --
                  IF (v_return_code > '0') THEN
                     om_log_batch_utl.prc_set_warning_on;
                     om_interface_log.prc_log_warning(
                        c_procedure_name,
                        'Failed to find BPS recovery STOB for BPS customer: ' || v_message,
                        'aset_rk= ' || r_recovery.aset_rk || ' customer class=' || v_customer_class_code,
                        r_recovery.aset_rk
                     );
                     --
                     -- default recovery stob if not found.
                     v_recovery_stob := fn_get_default_recovery_stob; --(v_customer_class_code); --temporary work around
                  END IF;
               END IF;
            --
            ELSE
               --
               -- get SDA party and account for TCA account.
               --
               OM_utl.prc_get_sda_ministry(n_account_id,
                                               n_sda_party_id,
                                               n_sda_account_id,
                                               v_return_code,
                                               v_message);

               --
               IF (v_return_code > 0) THEN
                  -- log failure to retrieve SDA account.
                  om_log_batch_utl.prc_set_warning_on;
                  om_interface_log.prc_log_warning(
                     c_procedure_name,
                     'Failed to retrieve SDA account: ' || v_message,
                        'aset_rk= '
                     || r_recovery.aset_rk
                     || ' TCA account ID='
                     || n_account_id
                     || ' cust class='
                     || v_customer_class_code,
                     r_recovery.aset_rk
                  );
               END IF;
            END IF;*/
         --
         END IF; -- TCA account found.

         --
         -- Extrace GL coding from item instance.
         -- It may change if it's invalid.
         v_expense_client := r_recovery.expense_client;
         v_expense_resp := r_recovery.expense_responsibility;
         v_expense_service := r_recovery.expense_service_line;
         v_expense_stob := r_recovery.expense_stob;
         v_expense_project := r_recovery.expense_project;
         v_expense_ccid := r_recovery.expense_ccid;
         --
        /*om_recover.prc_get_expense_coding(--r_recovery.istore_org,
                                pn_dflt_coding_flag_in,
                                --n_account_id,
                                v_expense_client,
                                v_expense_resp,
                                v_expense_service,
                                v_expense_stob,
                                v_expense_project,
                                v_expense_ccid,
                                v_default_expense_flag,
                                v_return_code,
                                v_message);
                                
*/
         --
         IF (v_expense_ccid IS NULL) THEN
            -- reset client, resp, svc, proj, which could now be null.
            v_expense_client := r_recovery.expense_client;
            v_expense_resp := r_recovery.expense_responsibility;
            v_expense_service := r_recovery.expense_service_line;
            v_expense_project := r_recovery.expense_project;

            --
            -- log invalid code combination for non-invoiced records (V6).
            --
           /* IF (v_customer_class_code != 'PUBLIC_SECTOR_INVOICED') THEN
               om_log_batch_utl.prc_set_warning_on;
               om_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Invalid expense GL code combination: ' || v_message,
                     'GL coding: '
                  || v_expense_client
                  || '.'
                  || v_expense_resp
                  || '.'
                  || v_expense_service
                  || '.'
                  || v_expense_stob
                  || '.'
                  || v_expense_project
                  || ' default coding='
                  || v_default_expense_flag
                  || ' class='
                  || v_customer_class_code,
                  r_recovery.aset_rk
               );
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
            END IF;*/
         --
         END IF;

         --
         v_po_number := fn_get_po_number(r_recovery.orde_rk);

         --
         -- write trace record to log if trace flag is on.
         --
         IF (pn_trace_flag_in = 1) THEN
            om_interface_log.prc_log_trace(
               c_procedure_name,
                  'TRACE: aset_rk='
               || r_recovery.aset_rk
               || ' recovery_started='
               || r_recovery.recovery_started
               || ' service_receipt_status='
               || r_recovery.service_receipt_status
               || ' recovery start='
               || TO_CHAR(d_recovery_period_start_date)
               || ' expense coding='
               || v_expense_client
               || '.'
               || v_expense_resp
               || '.'
               || v_expense_service
               || '.'
               || v_expense_stob
               || '.'
               || v_expense_project
               || ':'
               || v_expense_ccid
               || ' default coding='
               || v_default_expense_flag,
               NULL,
               r_recovery.aset_rk
            );
         END IF;

         --
         -- Create om_recoveries. If RECOVERY_STARTED=NO, then generate recoveries for
         -- all outstanding periods (exception for ONE TIME recoveries).
         IF (pn_trace_flag_in = 1) THEN
            om_interface_log.prc_log_trace(
               c_procedure_name,
               'TRACE: period cursor params',
                  'frequency='
               || v_recovery_frequency
               || ' r_recovery.recovery_started='
               || r_recovery.recovery_started
               || ' d_recovery_period_start_date='
               || d_recovery_period_start_date
               || ' r_recovery.recovery_start_date='
               || r_recovery.recovery_start_date
            );
         END IF;

         --
         v_period_found := 'N';

         --
         -- execute period loop only if no errors in recovery_start_date.
         IF (v_recovery_date_error = 'N') THEN -- V 8.1.
           --
           <<period_loop>>
            FOR r_period IN cr_recovery_periods(v_period_set_name,
                                                v_recovery_frequency,
                                                r_recovery.recovery_started,
                                                d_recovery_period_start_date,
                                                TO_DATE( r_recovery.recovery_start_date, 'YYYY/MM/DD hh24:mi:ss'),
                                                TO_DATE( r_recovery.recovery_end_date, 'YYYY/MM/DD hh24:mi:ss') -- V 8.0.
                                                                                                               -- new parameter to support modified CASE statement in query.
                                                ) LOOP
               --
               v_period_found := 'Y';
               -- period loop executed at least once.    Used below before updated extended attributes.
               --
               v_price_error_flag := 'N'; -- initialize price error flag.

               --
               IF (pn_trace_flag_in = 1) THEN
                  om_interface_log.prc_log_trace( c_procedure_name, 'TRACE: aset_rk=' || r_recovery.aset_rk || ' period=' || r_period.period_name);
               END IF;

               --
               -- get next reco_rk, if necessary.
               --
               IF (pn_validate_flag_in = 0) THEN -- V5.
                  --
                  --SELECT cas_ib_recovery_id_seq.NEXTVAL INTO n_recovery_id FROM DUAL;
                  SELECT RECO_RK_SEQ.NEXTVAL INTO n_reco_rk FROM DUAL;
               --
               END IF;

               --
               -- get item price if necessary - may be different for each recovery period.
               --
               IF (v_recovery_price_source = 'ORDER') THEN
                  n_order_price := TO_NUMBER(NVL(r_recovery.order_price, '0'));

                  -- log warning if order price is 0.
                  IF (n_order_price = 0) THEN
                     om_interface_log.prc_log_warning(c_procedure_name,
                                                       'Order price is zero.',
                                                       'aset_rk=' || r_recovery.aset_rk,
                                                       r_recovery.aset_rk,
                                                       n_reco_rk);
                  END IF;
               /*ELSE -- recovery price source defaults to ITEM if not found.
                  --
                  OM_utl.prc_get_item_price(r_recovery.seof_rk,
                                                v_customer_class_code,
                                                r_period.period_name,
                                                v_period_set_name,
                                                n_price,
                                                v_return_code,
                                                v_message);

                  --
                  IF (v_return_code > 0
                  AND v_customer_class_code IS NOT NULL) THEN
                     om_interface_log.prc_log_warning(
                        c_procedure_name,
                        'Item price error: ' || v_message,
                           'seof_rk='
                        || r_recovery.seof_rk
                        || ' customer_class_code='
                        || v_customer_class_code
                        || ' period='
                        || r_period.period_name,
                        r_recovery.aset_rk,
                        n_reco_rk
                     );
                     om_log_batch_utl.prc_set_warning_on;
                     v_price_error_flag := 'Y'; -- V 10 - BL - Mar 6/09.
                     n_error_count := n_error_count + 1;
                     n_price := 0;
                  ELSIF (n_price = 0) THEN
                     om_interface_log.prc_log_warning(c_procedure_name,
                                                       'Item price is zero.  (' || v_item_name || ')',
                                                       'aset_rk=' || r_recovery.aset_rk,
                                                       r_recovery.aset_rk,
                                                       n_reco_rk);
                  END IF;

                  --
                  -- check for potentially incorrect price source.
                  --
                  IF (NVL(r_recovery.order_price, 0) > 0
                  AND n_price = 0) THEN
                     om_interface_log.prc_log_warning(
                        c_procedure_name,
                           'Price source is ITEM but order price is non-null: '
                        || r_recovery.order_price
                        || ' ('
                        || v_item_name
                        || ')',
                        'aset_rk=' || r_recovery.aset_rk,
                        r_recovery.aset_rk,
                        n_reco_rk
                     );
                  END IF;*/
               --
               END IF;

               --
               -- log zero amount
               --
               --         IF (ROUND (r_recovery.quantity * n_price, 2) = 0) THEN
               --          cas_interface_log.prc_log_warning (c_procedure_name, 'Amount is zero.', 'instance_id=' || r_recovery.instance_id,
               --                         r_recovery.instance_id, n_reco_rk);
               --         END IF;
               --
               IF (r_period.period_year != n_recovery_period_year) THEN -- V7.
                  -- log previous fiscal recovery record.
                  --
                  SELECT DECODE(
                            v_price_error_flag, -- V 10.0 - BL - Mar 6/09.
                            'Y', 'E',
                            DECODE(
                               v_error_flag,
                               'Y', 'E',
                               /*DECODE(
                                  v_ministry_code,
                                  'WTS', 'W',*/
                                  DECODE(v_recovery_flag,
                                         'W', 'W',
                                         DECODE(SIGN(n_recovery_period_year - r_period.period_year), 0, 'I', 'F'))
                               )
                            )
                        -- )
                    INTO v_process_flag
                    FROM DUAL;

                  --
                  om_interface_log.prc_log_info(
                     c_procedure_name,
                     'Previous fiscal period ' || r_period.period_name || ', flag=' || v_process_flag,
                     'aset_rk=' || r_recovery.aset_rk,
                     r_recovery.aset_rk,
                     n_reco_rk
                  );
               END IF;

               --
               IF (pn_validate_flag_in = 0) THEN -- V5.
                  --
                  -- Insert recovery record.
                  --
                  BEGIN
                     INSERT
                       INTO OM_recoveries(reco_rk,
                                              --org_id,
                                              run_id,
                                              set_of_books_id,
                                              gl_period_name,
                                              recovery_period_name,
                                              seof_rk,
                                              --inv_master_organization_id,
                                              --aset_rk,
                                              asset_reference,
                                              consumption_id,
                                              adjustment_id,
                                              quantity,
                                              order_price,
                                              unit_of_measure,
                                              amount,
                                              recovery_type,
                                              expense_client,
                                              expense_responsibility,
                                              expense_service_line,
                                              expense_stob,
                                              expense_project,
                                              expense_ccid,
                                              default_expense_flag,
                                              recovery_client,
                                              recovery_responsibility,
                                              recovery_service_line,
                                              recovery_stob,
                                              recovery_project,
                                              /*owner_party_id,
                                              owner_party_account_id,
                                              tca_party_id,
                                              tca_account_id,
                                              tca_account_name,
                                              bill_to_site,
                                              bps_cost_centre,
                                              sda_party_id,
                                              sda_account_id,*/
                                              display_name,
                                              --customer_type,
                                              --customer_type,
                                              colour,
                                              asset_tag,
                                              order_po_number,
                                              --orde_rk,
                                              process_flag,
                                              --created_by,
                                              cre_user,
                                              cre_tmstmp, --creation_date,
                                              upd_user, --last_updated_by,
                                              upd_tmstmp) --last_updated_date)
                     VALUES (n_reco_rk,
                             /*NVL(r_recovery.last_vld_organization_id, r_recovery.inv_master_organization_id),*/ n_run_id,
                             pn_set_of_books_id_in, UPPER(pv_gl_period_in), r_period.period_name, r_recovery.seof_rk,
                             /*r_recovery.inv_master_organization_id, r_recovery.aset_rk,*/ r_recovery.asset_reference,
                             NULL, NULL, r_recovery.quantity, n_order_price, v_unit_of_measure, ROUND( r_recovery.quantity * n_order_price, 2),
                             pv_recovery_type_in, v_expense_client, v_expense_resp, v_expense_service, v_expense_stob,
                             v_expense_project, v_expense_ccid, v_default_expense_flag, v_recovery_client,
                             v_recovery_resp, v_recovery_service, v_recovery_stob, v_recovery_project, /*r_recovery.owner_party_id,
                             r_recovery.owner_party_account_id, n_party_id, n_account_id, v_account_name,
                             n_bill_to_address, r_recovery.bps_cost_centre,
                             NVL(n_sda_party_id, r_recovery.owner_party_id),
                             NVL(n_sda_account_id, r_recovery.owner_party_account_id),*/ r_recovery.display_name,
                             /*v_customer_class_code,*/ v_colour, r_recovery.asset_tag, v_po_number, --r_recovery.orde_rk,
                             --                DECODE (v_error_flag, 'Y', 'E', DECODE (v_ministry_code, 'WTS', 'W', 'I') ),
                             DECODE(v_price_error_flag, -- V 10.0 - BL - Mar 6/09.
                                                       'Y', 'E', DECODE(v_error_flag, 'Y', 'E', /*DECODE(v_ministry_code, 'WTS', 'W',*/ DECODE(v_recovery_flag, 'W', 'W', DECODE(SIGN(n_recovery_period_year - r_period.period_year), 0, 'I', 'F')))), --),
                             /*om_common_utl.fn_get_user_id('BATCH')*/'BATCH', SYSDATE, 'BATCH'/*om_common_utl.fn_get_user_id('BATCH')*/,
                             SYSDATE);
                  --
                  EXCEPTION
                     WHEN DUP_VAL_ON_INDEX THEN
                        n_existing_recovery_count := n_existing_recovery_count + 1;

                        IF (pn_trace_flag_in = 1) THEN
                           om_interface_log.prc_log_trace(
                              c_procedure_name,
                              'Duplicate recovery record: ' || SQLERRM,
                                 'aset_rk='
                              || r_recovery.aset_rk
                              || ' recovery_type='
                              || pv_recovery_type_in
                              || ' recovery_period='
                              || r_period.period_name,
                              r_recovery.aset_rk,
                              n_reco_rk
                           );
                        END IF;
                     WHEN OTHERS THEN
                        om_interface_log.prc_log_warning(
                           c_procedure_name,
                           'Recovery record insert error: ' || SQLERRM,
                              'aset_rk='
                           || r_recovery.aset_rk
                           || ' recovery_type='
                           || pv_recovery_type_in
                           || ' recovery_period='
                           || r_period.period_name,
                           r_recovery.aset_rk,
                           n_reco_rk
                        );
                        om_log_batch_utl.prc_set_warning_on;
                        v_recovery_insert_error := 'Y';
                        n_error_count := n_error_count + 1;
                  END;
               --
               END IF; -- validate=0.
            --
            END LOOP period_loop;
         END IF; -- no errors in recovery start/end dates.

         --
         -- Update the recovery_started attribute only if there was no error when inserting a
         -- recovery record for the current item instance.
         --
         IF (v_recovery_insert_error = 'N'
         AND v_period_found = 'Y' -- V 8.0.
         AND r_recovery.recovery_started = 'NO'
         AND pn_validate_flag_in = 0) THEN -- V5.
            --
            -- initialize extended attribute update table (passed to CAS_OM_UTL.cas_update_ib_attributes).
           /* t_attributes_tbl(1).column_name := 'recovery_started_flag';
            t_attributes_tbl(1).update_value := 'YES';

            --
            IF (pv_recovery_type_in = 'ONE TIME') THEN
               -- create extended attribute for recovery ID.
               t_attributes_tbl(2).column_name := 'reco_rk';
               t_attributes_tbl(2).update_value := TO_CHAR(n_reco_rk);
            --
            END IF;*/

            --
            BEGIN
               -- update recovery_started flag for this item instance.
              /* cas_om_utl.cas_update_ib_attributes(r_recovery.aset_rk,
                                                   --r_recovery.object_version_number,
                                                   NULL, -- context not required when only updating extended attribute.
                                                   t_attributes_tbl,
                                                   n_return_code,
                                                   v_message);

               --
               */
               IF (n_return_code > 0) THEN
                  om_interface_log.prc_log_warning(
                     c_procedure_name,
                     'Error encountered when updating item instance Recovery Started flag: ' || v_message,
                     r_recovery.aset_rk
                  );
                  om_log_batch_utl.prc_set_warning_on;
               END IF;
            --
            EXCEPTION
               WHEN OTHERS THEN
                  om_interface_log.prc_log_warning(c_procedure_name,
                                                    'IB update unexpected error: ' || SQLERRM,
                                                    NULL,
                                                    r_recovery.aset_rk);
                  om_log_batch_utl.prc_set_warning_on;
            END;
         END IF;
      -- recovery_started = NO and not pre-validation run, at least one period processed.
      --
      END LOOP instance_loop;

      --
      om_interface_log.prc_log_info( c_procedure_name, 'Rows processed: ' || TO_CHAR(n_total_count));
      om_interface_log.prc_log_info( c_procedure_name, 'Errors: ' || TO_CHAR(n_error_count));
      om_interface_log.prc_log_info( c_procedure_name, 'Existing recoveries: ' || TO_CHAR(n_existing_recovery_count));
      --
      om_log_batch_utl.prc_set_normal_end_of_package(c_procedure_name,
                                                      pv_return_code_out,
                                                      pv_message_out);
   --
   EXCEPTION
      WHEN OTHERS THEN
         om_interface_log.prc_log_info( c_procedure_name, 'Rows processed: ' || TO_CHAR(n_total_count));
         om_interface_log.prc_log_info( c_procedure_name, 'Errors: ' || TO_CHAR(n_error_count));
         om_interface_log.prc_log_info( c_procedure_name, 'Existing recoveries: ' || TO_CHAR(n_existing_recovery_count));
         om_interface_log.prc_log_error( c_procedure_name, 'prc_process_other(): unexpected error: ' || SQLERRM);
         om_log_batch_utl.prc_set_error_on;
         om_log_batch_utl.prc_set_error_end_of_package(c_procedure_name,
                                                        pv_return_code_out,
                                                        pv_message_out);
   END prc_process_other;

/*
   --
   --***************************************************************************************************
   --* Procedure : prc_process_consumption
   --* Purpose : Process consumption recoveries for given recovery fiscal period.
   --*  If the item instance has RECOVERY_STARTED=NO then recovery transactions will be
   --*  generated for all outstanding periods. (i.e. from item_instance.recovery_start_date
   --*  until end of given recovery period.
   --* Parameters: pv_recovery_period_in   - period for which recoveries are generated (e.g. APR-08).
   --*  pv_gl_period_in   - GL period to which recoveries are posted (e.g. MAY-08).
   --*  pn_set_of_books_id_in - set of books id (e.g. 16=BCGOV).
   --*  pn_run_id_out   - run id - generated by cas_interface_log package.
   --*  pv_return_code_out  - procedure return code ('0'=ok, '1'=warning, '2'=error).
   --*  pv_message_out   - optional output message.
   --*  pn_dflt_coding_flag_in  - optional input flag to use default coding if given coding is invalid.
   --*  pn_trace_flag_in  - optional input flag to enable tracing to cas_interface_logs.
   --*  pn_validate_flag_in   - optional flag to run validation checks only.
   --*  pv_customer_type_in   - optional customer type  (M=Ministry, B=BPS, null=both).
   --*  pn_owner_party_id_in   - optional owner_party_id to limit rows for testing.
   --*  pn_seof_rk_in  - optional pn_inventory_item_id_in to limit rows for testing.
   --* Called By :
   --***************************************************************************************************
   PROCEDURE prc_process_consumption(pv_recovery_period_in  IN            gl_periods.period_name%TYPE,
                                     pv_gl_period_in        IN            gl_periods.period_name%TYPE,
                                     pn_set_of_books_id_in  IN            gl_sets_of_books.set_of_books_id%TYPE,
                                     pn_run_id_out             OUT NOCOPY cas_interface_logs.run_id%TYPE,
                                     pv_return_code_out        OUT NOCOPY VARCHAR2,
                                     pv_message_out            OUT NOCOPY VARCHAR2,
                                     pn_dflt_coding_flag_in IN            NUMBER,
                                     pn_trace_flag_in       IN            NUMBER,
                                     pn_validate_flag_in    IN            NUMBER,
                                     pv_customer_type_in    IN            VARCHAR2,
                                     pn_owner_party_id_in   IN            csi_item_instances.owner_party_id%TYPE --      pn_inventory_item_id_in IN            csi_item_instances.inventory_item_id%TYPE
                                                                                                                ) IS
      --

      -- Alert # 191418

      n_cas_bps_cost_centre          NUMBER;
      -- define constant for procedure name; used in calls to CAS_INTERFACE_LOG package.
      c_procedure_name      CONSTANT VARCHAR2(30) := 'prc_process_consumption';

      --
      -- cursor to select item instances to generate recovery transactions.
      --
      -- Alert 202659 - party_id parameter no longer required
      CURSOR cr_ib_recoveries( --cn_wts_party_id    IN hz_parties.party_id%TYPE,
                              cd_period_end_date IN DATE) IS
         SELECT cons.consumption_id,
                cons.consumption_period_name,
                item_instance.instance_id,
                item_instance.instance_number,
                item_instance.object_version_number,
                item_instance.inventory_item_id,
                cons.inventory_item_id cons_item_id,
                item_instance.inv_master_organization_id,
                item_instance.last_vld_organization_id,
                item_instance.external_reference,
                item_instance.last_oe_order_line_id,
                --                cas_ib_utl.fn_select_extended_attribute( item_instance.instance_id, n_cas_bps_cost_centre)
                --                   bps_cost_centre, -- Alert # 191418
                (SELECT MAX(attribute_value)
                   FROM om.om_arp_values
                  WHERE instance_id = item_instance.instance_id
                    AND attribute_id = n_cas_bps_cost_centre)
                   bps_cost_centre,
                cons.quantity,
                item_instance.unit_of_measure,
                item_instance.attribute1 expense_client,
                item_instance.attribute2 expense_responsibility,
                item_instance.attribute3 expense_service_line,
                item_instance.attribute4 expense_stob,
                item_instance.attribute5 expense_project,
                item_instance.attribute6 expense_ccid,
                item_instance.owner_party_id,
                item_instance.owner_party_account_id,
                item_instance.attribute7 description,
                item_instance.attribute10 istore_org,
                item_instance.attribute12 recovery_frequency,
                item_instance.attribute13 order_price
           FROM cas_ib_consumption cons,
                csi_item_instances item_instance,
                cas_ib_service_receipt sr
          WHERE cons.recovery_status = 'PENDING'
            AND cons.consumption_period <= cd_period_end_date
            AND item_instance.instance_id = cons.instance_id
            AND ((pv_customer_type_in = 'B'
              AND item_instance.owner_party_id IN (SELECT key
                                                     FROM casint.cas_generic_table_details
                                                    WHERE category = 'CAS_BPS_PARTY_IDS'))
              OR (pv_customer_type_in = 'M'
              AND item_instance.owner_party_id NOT IN (SELECT key
                                                         FROM casint.cas_generic_table_details
                                                        WHERE category = 'CAS_BPS_PARTY_IDS'))
              OR pv_customer_type_in IS NULL)
            AND sr.instance_id = item_instance.instance_id
            AND sr.service_receipt_status IN ('RECEIVED', 'NOT REQUIRED', 'DEEMED RECEIVED')
         ORDER BY cons.inventory_item_id;

      --
      d_recovery_period_start_date   gl_periods.start_date%TYPE;
      d_recovery_period_end_date     gl_periods.end_date%TYPE;
      n_recovery_period_year         gl_periods.period_year%TYPE;
      n_cons_period_year             gl_periods.period_year%TYPE;
      v_period_set_name              gl_periods.period_set_name%TYPE;
      n_recovery_id                  cas_ib_recoveries.recovery_id%TYPE;
      --   v_service    mtl_descr_element_values.element_value%TYPE;
      --   v_service_family   mtl_descr_element_values.element_value%TYPE;
      --   v_service_group    mtl_descr_element_values.element_value%TYPE;
      --   v_service_category   mtl_descr_element_values.element_value%TYPE;
      --   v_ccid     csi_item_instances.attribute6%TYPE;
      v_default_expense_flag         VARCHAR2(1) := 'N';
      --   v_customer_info_rc   VARCHAR2 (1);
      --   v_customer_info_msg  VARCHAR2 (4000);
      --   v_sda_account_rc   VARCHAR2 (1);
      --   v_sda_account_msg  VARCHAR2 (4000);
      --   v_recovery_price_rc  VARCHAR2 (1);
      --   v_recovery_price_msg   VARCHAR2 (4000);
      v_process_flag                 cascsi.cas_ib_recoveries.process_flag%TYPE;
      v_return_code                  VARCHAR2(1);
      v_message                      VARCHAR2(4000);
      v_customer_class_code          hz_cust_accounts.customer_class_code%TYPE;
      n_account_id                   hz_cust_accounts.cust_account_id%TYPE;
      n_sda_account_id               hz_cust_accounts.cust_account_id%TYPE;
      v_account_number               hz_cust_accounts.account_number%TYPE;
      v_account_name                 hz_cust_accounts.account_name%TYPE;
      v_ministry_code                hz_cust_accounts.account_name%TYPE;
      -- WENDM - Feb 15 new fundiing model.START
      v_recovery_flag                VARCHAR2(1); -- Recover Y or N
      -- WENDM - Feb 15 new fundiing model.END
      n_party_id                     hz_cust_accounts.party_id%TYPE;
      n_sda_party_id                 hz_cust_accounts.party_id%TYPE;
      n_bill_to_address              csi_ip_accounts.bill_to_address%TYPE;
      --
      --   v_recovery_coding_rc   VARCHAR2 (1);
      --   v_recovery_coding_msg  VARCHAR2 (4000);
      v_recovery_client              csi_item_instances.attribute1%TYPE;
      v_recovery_resp                csi_item_instances.attribute2%TYPE;
      v_recovery_service             csi_item_instances.attribute3%TYPE;
      v_recovery_stob                csi_item_instances.attribute4%TYPE;
      v_save_stob                    csi_item_instances.attribute4%TYPE;
      v_recovery_project             csi_item_instances.attribute5%TYPE;
      --
      v_expense_client               csi_item_instances.attribute1%TYPE;
      v_expense_resp                 csi_item_instances.attribute2%TYPE;
      v_expense_service              csi_item_instances.attribute3%TYPE;
      v_expense_stob                 csi_item_instances.attribute4%TYPE;
      v_expense_project              csi_item_instances.attribute5%TYPE;
      v_expense_ccid                 csi_item_instances.attribute6%TYPE;
      v_po_number                    oe_order_headers_all.cust_po_number%TYPE;
      --
      v_recovery_price_source        mtl_descr_element_values.element_value%TYPE;
      v_colour                       mtl_descr_element_values.element_value%TYPE;
      v_reporting_uom                mtl_descr_element_values.element_value%TYPE;
      v_item_name                    mtl_system_items_b.segment1%TYPE;
      v_item_uom                     mtl_system_items_b.primary_uom_code%TYPE;
      n_prev_inventory_item_id       mtl_system_items_b.inventory_item_id%TYPE := 0;
      n_price                        NUMBER;
      n_run_id                       cas_interface_logs.run_id%TYPE;
      -- Alert 202659 - n_wts_party_id no longer required
      --  n_wts_party_id                        hz_parties.party_id%TYPE;
      --
      -- The flags below indicate error conditions with item or item_instance that
      -- would prevent the recovery transaction from being processed successfully.
      -- Used when setting the transaction process_flag column.
      --
      v_error_flag                   VARCHAR2(1); -- problem with item (Y/N).
      n_error_count                  NUMBER := 0;
      -- number of records with a problem
      n_total_count                  NUMBER := 0;
   -- total number of consumption records processed
   --
   BEGIN
      --

      -- Alert # 191418
      n_cas_bps_cost_centre := cas_ib_utl.fn_get_attribute_id('CAS_BPS_COST_CENTRE');

      -- log start of recovery run
      --
      cas_log_batch_utl.prc_start_package(
         'CAS IB Recoveries',
         'CAS_IB_RECOVER',
         gc_version_no,
         gc_version_dt,
         c_procedure_name,
            ' recovery type=Consumption recovery_period='
         || pv_recovery_period_in
         || ' gl_period='
         || pv_gl_period_in
         || ' set_of_books_id='
         || pn_set_of_books_id_in
         || ' trace='
         || pn_trace_flag_in
         || ' validate='
         || pn_validate_flag_in
         || ' customer_type='
         || pv_customer_type_in
         || ' owner_party_id='
         || pn_owner_party_id_in
      --         || ' inventory_item_id='
      --         || pn_inventory_item_id_in
      );
      --
      -- get current run_id (entered on each IB_recovery row).
      --
      n_run_id := cas_interface_log.fn_run_id;
      pn_run_id_out := n_run_id;

      -- Alert 202659 - BCAS recoveries - move check for BPS party table to main procedure
      --
      -- get info re: set of books
      --
      cas_ib_utl.prc_select_set_of_books(pn_set_of_books_id_in,
                                         v_period_set_name,
                                         v_return_code,
                                         v_message);

      --
      IF (v_return_code > 0) THEN
         raise_application_error( -20000, 'Error retrieving set of books info for id=' || pn_set_of_books_id_in || ': ' || v_message);
      END IF;

      --
      -- validate GL period name.
      --
      IF (NOT fn_is_valid_period_name( v_period_set_name, pv_gl_period_in)) THEN
         raise_application_error( -20000, 'Invalid GL period name: ' || pv_gl_period_in);
      END IF;

      --
      -- get recovery period start/end dates
      --
      cas_ib_utl.prc_get_gl_period_dates(v_period_set_name,
                                         UPPER(pv_recovery_period_in),
                                         d_recovery_period_start_date,
                                         d_recovery_period_end_date,
                                         n_recovery_period_year,
                                         v_return_code,
                                         v_message);

      --
      IF (v_return_code > 0) THEN
         raise_application_error( -20000, 'Error retrieving period start/end dates for recovery period ' || pv_recovery_period_in || ': ' || v_message);
      END IF;

     --
     -- Loop through consumption records to process recoveries.
     --
     <<instance_loop>>
      -- Alert 202659 - n_wts_party_id parameter no longer required
      FOR r_recovery IN cr_ib_recoveries(d_recovery_period_end_date) LOOP
         --
         n_total_count := n_total_count + 1;
         --
         v_error_flag := 'N'; -- initialize item instance error flag.
         n_price := 0; -- initialize price

         --
         -- When inventory_item_id changes, get item name, recovery source and recovery coding.
         --
         IF (r_recovery.cons_item_id != n_prev_inventory_item_id) THEN
            --
            v_error_flag := 'N'; -- reset item error flag.

            --
            -- get name of current item
            --
            SELECT segment1 item_name, primary_uom_code
              INTO v_item_name, v_item_uom
              FROM mtl_system_items_b
             WHERE inventory_item_id = r_recovery.cons_item_id
               AND organization_id = r_recovery.inv_master_organization_id;

            --
            -- get recovery price source for current item (i.e. ITEM or ORDER).
            --
            v_recovery_price_source := cas_ib_utl.fn_select_catalog_element( r_recovery.cons_item_id, 'Recovery Price Source');

            --
            IF (v_recovery_price_source IS NULL) THEN
               -- log missing recovery price source
               cas_log_batch_utl.prc_set_warning_on;
               cas_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Item recovery price source is missing or blank; defaulted to ITEM ',
                  'instance_id=' || r_recovery.instance_id || ' inventory_item_id=' || r_recovery.cons_item_id,
                  r_recovery.consumption_id
               );
            END IF;

            --
            v_colour := cas_ib_utl.fn_select_catalog_element( r_recovery.cons_item_id, 'Colour');

            --
            IF (v_colour IS NULL) THEN
               -- log missing colour
               cas_log_batch_utl.prc_set_warning_on;
               cas_interface_log.prc_log_warning(c_procedure_name,
                                                 'Item colour is missing or blank.',
                                                 'inventory_item_id=' || r_recovery.inventory_item_id,
                                                 r_recovery.consumption_id);
            --
            END IF;

            --
            IF (pn_trace_flag_in = 1) THEN
               cas_interface_log.prc_log_trace(
                  c_procedure_name,
                     'TRACE: Processing inventory_item_id='
                  || r_recovery.cons_item_id
                  || ' ('
                  || v_item_name
                  || ') Recovery Price Source='
                  || v_recovery_price_source
                  || ' Reporting UOM='
                  || v_reporting_uom
                  || ' Colour='
                  || v_colour,
                  'instance_id=' || r_recovery.instance_id || ' inventory_item_id=' || r_recovery.cons_item_id
               );
            END IF;

            --
            -- get recovery GL coding for current item
            --
            cas_ib_utl.prc_select_recovery_coding(r_recovery.cons_item_id,
                                                  v_recovery_client,
                                                  v_recovery_resp,
                                                  v_recovery_service,
                                                  v_recovery_stob,
                                                  v_recovery_project,
                                                  v_return_code,
                                                  v_message);
            --
            -- save stob - may need to reset v_recovery_stob if it's changed for a BPS invoice recovery.
            v_save_stob := v_recovery_stob;

            --
            IF (v_return_code > 0
             OR v_recovery_client IS NULL
             OR v_recovery_resp IS NULL
             OR v_recovery_service IS NULL
             OR v_recovery_stob IS NULL
             OR v_recovery_project IS NULL) THEN
               -- log recovery coding error.
               cas_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Recovery coding error: ' || v_message,
                  'instance_id=' || r_recovery.instance_id || ' inventory_item_id=' || r_recovery.cons_item_id,
                  r_recovery.consumption_id
               );
               cas_log_batch_utl.prc_set_warning_on;
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
            END IF;

            --
            IF (pn_trace_flag_in = 1) THEN
               cas_interface_log.prc_log_trace( c_procedure_name, 'TRACE: recovery coding=' || v_recovery_client || '.' || v_recovery_resp || '.' || v_recovery_service || '.' || v_recovery_stob || '.' || v_recovery_project);
            --
            END IF;

            --
            n_prev_inventory_item_id := r_recovery.cons_item_id;
         --
         ELSE
            -- reset recovery stob in case it's been changed for a BPS invoice recovery.
            v_recovery_stob := v_save_stob;
         --
         END IF; -- new inventory_item_id.

         --
         -- get customer info
         --
         cas_ib_utl.prc_select_customer_info(r_recovery.instance_id,
                                             v_customer_class_code,
                                             n_account_id,
                                             v_account_number,
                                             v_account_name,
                                             n_party_id,
                                             n_bill_to_address,
                                             v_return_code,
                                             v_message);

         --
         IF (v_return_code > 0) THEN
            -- log failure to retrieve customer info.
            cas_log_batch_utl.prc_set_warning_on;
            cas_interface_log.prc_log_warning(
               c_procedure_name,
               'Failed to retrieve customer class and/or TCA account/party info: ' || v_message,
                  'instance_id= '
               || r_recovery.instance_id
               || ' TCA Account ID='
               || TO_CHAR(n_account_id)
               || ' customer class='
               || v_customer_class_code,
               r_recovery.consumption_id
            );
            v_error_flag := 'Y';
            n_error_count := n_error_count + 1;
            --
            v_ministry_code := '';
         --
         ELSE
            -- check customer class consistent with customer type input parameter.
            -- Alert 202659 - new function fn_isbps() used to determine if party is BPS
            IF (fn_isbps(r_recovery.owner_party_id) = 1
            AND v_customer_class_code NOT LIKE 'PUBLIC_SECTOR%'
             OR fn_isbps(r_recovery.owner_party_id) = 0
            AND v_customer_class_code NOT LIKE 'MINISTRY%') THEN
               -- log inconsistency between owner_party and cust_class.
               cas_log_batch_utl.prc_set_warning_on;
               cas_interface_log.prc_log_warning(
                  c_procedure_name,
                     'Owner party_id '
                  || r_recovery.owner_party_id
                  || ' is inconsistent with customer class '
                  || v_customer_class_code,
                  'instance_id= ' || r_recovery.instance_id || ' TCA Account ID=' || TO_CHAR(n_account_id),
                  r_recovery.consumption_id
               );
               --
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
            --
            END IF;

            -- parse ministry code from TCA name. Get the string between the two dashes.
            -- This is used to check for 'WTS' when setting the recovery process flag.
            v_ministry_code := SUBSTR(v_account_name,
                                      5,
                                      INSTR(v_account_name,
                                      '-',
                                      5) - 5);

            ---------------------------------------------------------------------------------------------
            -- WENDM get recovery flag using cust_account_id, cust_account_number and cust_account name
            -- returned from the above lookup. Return upper case Y or N.
            -- Colour BLUE is hardcoded for now but can be putin cas_generci tables.
            -- All records with PROCESS_FLAG of W in cas_ib_recoveries will be ignored by recovery JV process.
            IF v_ministry_code = 'WTS' THEN
               v_recovery_flag := 'W';
            ELSIF (SUBSTR(v_customer_class_code,
                          1,
                          8) = 'MINISTRY') THEN
               v_recovery_flag := fn_get_recovery_flag(n_account_id,
                                                       v_account_number,
                                                       v_account_name,
                                                       v_colour);
            ELSE
               v_recovery_flag := 'I';
            END IF;

            --
            --
            IF (SUBSTR(v_customer_class_code,
                       1,
                       8) != 'MINISTRY') THEN
               -- default SDA account ID to owner_party account ID for non-ministry customers.
               n_sda_account_id := r_recovery.owner_party_account_id;
               n_sda_party_id := r_recovery.owner_party_id;

               --
               -- check for BPS customer type and replace recovery stob if necessary.
               --    IF (fn_is_bps (v_customer_class_code) ) THEN
               IF (v_customer_class_code = 'PUBLIC_SECTOR_INVOICED') THEN
                  cas_ib_utl.prc_get_bps_recoveries_stob(r_recovery.instance_id,
                                                         v_recovery_stob,
                                                         v_return_code,
                                                         v_message);

                  --
                  IF (v_return_code > '0') THEN
                     cas_log_batch_utl.prc_set_warning_on;
                     cas_interface_log.prc_log_warning(
                        c_procedure_name,
                        'Failed to find BPS recovery STOB for BPS customer: ' || v_message,
                        'instance_id= ' || r_recovery.instance_id || ' customer class=' || v_customer_class_code,
                        r_recovery.consumption_id
                     );
                     --
                     -- default recovery stob if not found.
                     v_recovery_stob := fn_get_default_recovery_stob(v_customer_class_code);
                  END IF;
               END IF;
            ELSE
               --
               -- get SDA party and account for TCA account.
               --
               cas_ib_utl.prc_get_sda_ministry(n_account_id,
                                               n_sda_party_id,
                                               n_sda_account_id,
                                               v_return_code,
                                               v_message);

               --
               IF (v_return_code > 0) THEN
                  -- log failure to retrieve SDA account.
                  --   v_error_flag := 'Y';
                  cas_log_batch_utl.prc_set_warning_on;
                  cas_interface_log.prc_log_warning(
                     c_procedure_name,
                     'Failed to retrieve SDA account: ' || v_message,
                     'instance_id= ' || r_recovery.instance_id || ' TCA account ID=' || n_account_id,
                     r_recovery.consumption_id
                  );
               --    n_error_count := n_error_count + 1;
               END IF;
            END IF;
         --
         END IF;

         --
         -- Extrace GL coding from item instance.
         -- It may change if it's invalid.
         v_expense_client := r_recovery.expense_client;
         v_expense_resp := r_recovery.expense_responsibility;
         v_expense_service := r_recovery.expense_service_line;
         v_expense_stob := r_recovery.expense_stob;
         v_expense_project := r_recovery.expense_project;
         v_expense_ccid := r_recovery.expense_ccid;
         --
         prc_get_expense_coding(r_recovery.istore_org,
                                pn_dflt_coding_flag_in,
                                n_account_id,
                                v_expense_client,
                                v_expense_resp,
                                v_expense_service,
                                v_expense_stob,
                                v_expense_project,
                                v_expense_ccid,
                                v_default_expense_flag,
                                v_return_code,
                                v_message);

         --
         IF (v_expense_ccid IS NULL) THEN
            -- reset client, resp, svc, proj, which could now be null.
            v_expense_client := r_recovery.expense_client;
            v_expense_resp := r_recovery.expense_responsibility;
            v_expense_service := r_recovery.expense_service_line;
            v_expense_project := r_recovery.expense_project;

            --
            IF (v_customer_class_code != 'PUBLIC_SECTOR_INVOICED') THEN
               -- log invalid code combination for non-invoiced records.
               cas_log_batch_utl.prc_set_warning_on;
               cas_interface_log.prc_log_warning(
                  c_procedure_name,
                     'Invalid expense GL code combination: '
                  || v_message
                  || ' '
                  || v_expense_client
                  || '.'
                  || v_expense_resp
                  || '.'
                  || v_expense_service
                  || '.'
                  || v_expense_stob
                  || '.'
                  || v_expense_project
                  || ' default coding='
                  || v_default_expense_flag,
                  r_recovery.consumption_id
               );
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
            END IF;
         --
         END IF;

         --
         v_po_number := fn_get_po_number(r_recovery.last_oe_order_line_id);

         --
         -- write trace record to log if trace flag is on.
         --
         IF (pn_trace_flag_in = 1) THEN
            cas_interface_log.prc_log_trace( c_procedure_name, 'TRACE: instance_id=' || r_recovery.instance_id || ' expense coding=' || r_recovery.expense_client || '.' || r_recovery.expense_responsibility || '.' || r_recovery.expense_service_line || '.' || r_recovery.expense_stob || '.' || r_recovery.expense_project || ':' || r_recovery.expense_ccid);
         END IF;

         --
         -- get item price
         --
         IF (v_recovery_price_source = 'ORDER') THEN
            n_price := TO_NUMBER(NVL(r_recovery.order_price, '0'));

            -- log warning if order price is 0.
            IF (n_price = 0) THEN
               cas_interface_log.prc_log_warning(c_procedure_name,
                                                 'Order price is zero.',
                                                 'instance_id=' || r_recovery.instance_id,
                                                 r_recovery.consumption_id,
                                                 n_recovery_id);
            END IF;
         ELSE
            -- v_recovery_price_source = 'ITEM'.
            cas_ib_utl.prc_get_item_price(r_recovery.cons_item_id,
                                          v_customer_class_code,
                                          r_recovery.consumption_period_name,
                                          v_period_set_name,
                                          n_price,
                                          v_return_code,
                                          v_message);

            --
            IF (v_return_code > 0
            AND v_customer_class_code IS NOT NULL) THEN
               cas_interface_log.prc_log_warning(
                  c_procedure_name,
                  'Item price error: ' || v_message,
                     'instance_id='
                  || r_recovery.instance_id
                  || 'inventory_item_id='
                  || r_recovery.cons_item_id
                  || ' customer_class_code='
                  || v_customer_class_code
                  || ' period='
                  || r_recovery.consumption_period_name,
                  r_recovery.consumption_id,
                  n_recovery_id
               );
               cas_log_batch_utl.prc_set_warning_on;
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
               n_price := 0;
            ELSIF (n_price = 0) THEN
               cas_interface_log.prc_log_warning(c_procedure_name,
                                                 'Item price is zero.  (' || v_item_name || ')',
                                                 'instance_id=' || r_recovery.instance_id,
                                                 r_recovery.consumption_id,
                                                 n_recovery_id);
            END IF;

            --
            -- check for potentially incorrect price source.
            --
            IF (NVL(r_recovery.order_price, 0) > 0
            AND n_price = 0) THEN
               cas_interface_log.prc_log_warning(
                  c_procedure_name,
                     'Price source is ITEM but order price is non-null: '
                  || r_recovery.order_price
                  || ' ('
                  || v_item_name
                  || ')',
                  'instance_id=' || r_recovery.instance_id,
                  r_recovery.consumption_id,
                  n_recovery_id
               );
            END IF;
         END IF;

         --
         -- log zero amount
         --
         --   IF (ROUND (r_recovery.quantity * n_price, 2) = 0) THEN
         --    cas_interface_log.prc_log_warning (c_procedure_name, 'Amount is zero.', 'instance_id=' || r_recovery.instance_id,
         --       r_recovery.instance_id, n_recovery_id);
         --   END IF;
         --
         --
         -- get consumption period year - compare with recovery period year - flag previous fiscal items.
         --
         SELECT period_year
           INTO n_cons_period_year
           FROM gl.gl_periods glp
          WHERE glp.period_set_name = v_period_set_name
            AND glp.period_name = r_recovery.consumption_period_name;

         --
         IF (n_cons_period_year != n_recovery_period_year) THEN -- V7.
            --
            -- log previous fiscal recovery record.
            --
            SELECT DECODE(
                      v_error_flag,
                      'Y', 'E',
                      DECODE(
                         v_ministry_code,
                         'WTS', 'W',
                         DECODE(v_recovery_flag,
                                'W', 'W',
                                DECODE(SIGN(n_recovery_period_year - n_cons_period_year), 0, 'I', 'F'))
                      )
                   )
              INTO v_process_flag
              FROM DUAL;

            --
            cas_interface_log.prc_log_info(
               c_procedure_name,
               'Previous fiscal period ' || r_recovery.consumption_period_name || ', flag=' || v_process_flag,
               'instance_id=' || r_recovery.instance_id || ' inventory_item_id=' || r_recovery.cons_item_id,
               r_recovery.consumption_id,
               n_recovery_id
            );
         END IF;

         --
         IF (pn_validate_flag_in = 0) THEN -- V5.
            --
            -- get next recovery_id.
            --
            SELECT cas_ib_recovery_id_seq.NEXTVAL INTO n_recovery_id FROM DUAL;

            --
            -- insert recovery record.
            --
            BEGIN
               INSERT
                 INTO cas_ib_recoveries(recovery_id,
                                        org_id,
                                        run_id,
                                        set_of_books_id,
                                        gl_period_name,
                                        recovery_period_name,
                                        inventory_item_id,
                                        inv_master_organization_id,
                                        instance_id,
                                        instance_number,
                                        consumption_id,
                                        adjustment_id,
                                        quantity,
                                        price,
                                        item_uom,
                                        amount,
                                        recovery_type,
                                        expense_client,
                                        expense_responsibility,
                                        expense_service_line,
                                        expense_stob,
                                        expense_project,
                                        expense_ccid,
                                        default_expense_flag,
                                        recovery_client,
                                        recovery_responsibility,
                                        recovery_service_line,
                                        recovery_stob,
                                        recovery_project,
                                        owner_party_id,
                                        owner_party_account_id,
                                        tca_party_id,
                                        tca_account_id,
                                        tca_account_name,
                                        bill_to_site,
                                        bps_cost_centre,
                                        sda_party_id,
                                        sda_account_id,
                                        display_name,
                                        customer_class,
                                        colour,
                                        external_reference,
                                        order_po_number,
                                        last_oe_order_line_id,
                                        process_flag,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_updated_date)
               VALUES (
                         n_recovery_id, NVL(r_recovery.last_vld_organization_id, r_recovery.inv_master_organization_id),
                         n_run_id, pn_set_of_books_id_in, UPPER(pv_gl_period_in), r_recovery.consumption_period_name,
                         r_recovery.cons_item_id, r_recovery.inv_master_organization_id, r_recovery.instance_id,
                         r_recovery.instance_number, r_recovery.consumption_id, NULL, r_recovery.quantity, n_price,
                         v_item_uom, ROUND( r_recovery.quantity * n_price, 2), 'CGI', v_expense_client, v_expense_resp,
                         v_expense_service, v_expense_stob, v_expense_project, v_expense_ccid, v_default_expense_flag,
                         v_recovery_client, v_recovery_resp, v_recovery_service, v_recovery_stob, v_recovery_project,
                         r_recovery.owner_party_id, r_recovery.owner_party_account_id, n_party_id, n_account_id,
                         v_account_name, n_bill_to_address, r_recovery.bps_cost_centre,
                         NVL(n_sda_party_id, r_recovery.owner_party_id),
                         NVL(n_sda_account_id, r_recovery.owner_party_account_id), r_recovery.display_name,
                         v_customer_class_code, v_colour, r_recovery.external_reference, v_po_number, r_recovery.last_oe_order_line_id,
                         --    DECODE (v_error_flag, 'Y', 'E', DECODE (v_ministry_code, 'WTS', 'W', 'I') ),
                         DECODE(v_error_flag, 'Y', 'E', DECODE(v_ministry_code, 'WTS', 'W', DECODE(v_recovery_flag, 'W', 'W', DECODE(SIGN(n_recovery_period_year - n_cons_period_year), 0, 'I', 'F')))),
                         cas_common_utl.fn_get_user_id('BATCH'), SYSDATE, cas_common_utl.fn_get_user_id('BATCH'),
                         SYSDATE
                      );

               --
               -- update consumption record status
               --
               UPDATE cas_ib_consumption
                  SET recovery_status = 'RECOVERED',
                      recovery_id = n_recovery_id,
                      last_updated_by = cas_common_utl.fn_get_user_id('BATCH'),
                      last_update_date = SYSDATE
                WHERE consumption_id = r_recovery.consumption_id;
            --
            EXCEPTION
               WHEN OTHERS THEN
                  cas_interface_log.prc_log_warning(
                     c_procedure_name,
                     SQLERRM,
                        'instance_id='
                     || r_recovery.instance_id
                     || ' recovery_period='
                     || r_recovery.consumption_period_name,
                     r_recovery.consumption_id
                  );
                  cas_log_batch_utl.prc_set_warning_on;
                  v_error_flag := 'Y';
                  n_error_count := n_error_count + 1;
            END;
         END IF; -- not validate
      --
      END LOOP instance_loop;

      --
      cas_interface_log.prc_log_info( c_procedure_name, 'Rows processed: ' || TO_CHAR(n_total_count) || ' Errors: ' || TO_CHAR(n_error_count));
      --
      cas_log_batch_utl.prc_set_normal_end_of_package(c_procedure_name,
                                                      pv_return_code_out,
                                                      pv_message_out);
   --
   EXCEPTION
      WHEN OTHERS THEN
         cas_interface_log.prc_log_error( c_procedure_name, 'Consumption recoveries unexpected error: ' || SQLERRM);
         cas_log_batch_utl.prc_set_error_on;
         cas_log_batch_utl.prc_set_error_end_of_package(c_procedure_name,
                                                        pv_return_code_out,
                                                        pv_message_out);
   END prc_process_consumption;
*/
/*
   --
   --***************************************************************************************************
   --* Procedure : prc_process_credits
   --* Purpose : Process credits for cancelled monthly instances in the given recovery period.
   --* Parameters: pv_recovery_period_in   - period for which recoveries are generated (e.g. APR-08).
   --*  pv_gl_period_in   - GL period to which recoveries are posted (e.g. MAY-08).
   --*  pn_set_of_books_id_in - set of books id (e.g. 16=BCGOV).
   --*  pn_run_id_out   - run id - generated by cas_interface_log package.
   --*  pv_return_code_out  - procedure return code ('0'=ok, '1'=warning, '2'=error).
   --*  pv_message_out   - optional output message.
   --*  pn_trace_flag_in  - optional input flag to enable tracing to cas_interface_logs.
   --*  pn_validate_flag_in   - optional flag to run validation checks only.
   --*  pv_customer_type_in   - optional customer type  (M=Ministry, B=BPS, null=both).
   --***************************************************************************************************
   PROCEDURE prc_process_credits(pv_recovery_period_in IN            gl_periods.period_name%TYPE,
                                 pv_gl_period_in       IN            gl_periods.period_name%TYPE,
                                 pn_set_of_books_id_in IN            gl_sets_of_books.set_of_books_id%TYPE,
                                 pn_run_id_out            OUT NOCOPY cas_interface_logs.run_id%TYPE,
                                 pv_return_code_out       OUT NOCOPY VARCHAR2,
                                 pv_message_out           OUT NOCOPY VARCHAR2,
                                 pn_trace_flag_in      IN            NUMBER,
                                 pn_validate_flag_in   IN            NUMBER,
                                 pv_customer_type_in   IN            VARCHAR2) IS
      --
      -- define constant for procedure name; used in calls to CAS_INTERFACE_LOG package.
      c_procedure_name      CONSTANT VARCHAR2(30) := 'prc_process_credits';

      --
      -- cursor to select item instances to generate recovery transactions.
      --
      -- Alert 202659 - wts_party_id parameter no longer required
      CURSOR cr_credit_recoveries(cv_period_set_name IN VARCHAR2) IS
         SELECT --/*+  parallel (eav_cancel 4)
         parallel (ii 4)
         parallel (eav_enddt 4)
         parallel (pd 4)
        *\ -- changed back slash to forward slash
               pd.period_year, ii.object_version_number, r.*
           FROM csi.csi_i_extended_attribs ea_cancel,
                om.om_arp_values eav_cancel,
                csi.csi_item_instances ii,
                (SELECT eav.instance_id, eav.attribute_value enddt
                   FROM csi.csi_i_extended_attribs ea_enddt,
                        om.om_arp_values eav
                  WHERE ea_enddt.attribute_code = 'CAS_RECOVERY_END_DATE'
                    AND eav.attribute_id = ea_enddt.attribute_id
                    AND eav.attribute_value LIKE '2%') eav_enddt,
                cascsi.cas_ib_recoveries r,
                gl.gl_periods pd
          WHERE ea_cancel.attribute_code = 'CAS_CANCEL_IB_INSTANCE'
            AND eav_cancel.attribute_id = ea_cancel.attribute_id
            AND ii.instance_id = eav_cancel.instance_id
            AND ((pv_customer_type_in = 'B'
              AND ii.owner_party_id IN (SELECT key
                                          FROM casint.cas_generic_table_details
                                         WHERE category = 'CAS_BPS_PARTY_IDS'))
              OR (pv_customer_type_in = 'M'
              AND ii.owner_party_id NOT IN (SELECT key
                                              FROM casint.cas_generic_table_details
                                             WHERE category = 'CAS_BPS_PARTY_IDS'))
              OR pv_customer_type_in IS NULL)
            AND eav_enddt.instance_id = ii.instance_id
            AND r.instance_id = ii.instance_id
            AND r.process_flag IN ('I', 'P')
            AND r.recovery_type = 'MONTHLY'
            AND pd.period_name = r.recovery_period_name
            AND pd.period_set_name = cv_period_set_name
            AND pd.end_date > TO_DATE( eav_enddt.enddt, 'YYYY/MM/DD hh24:mi:ss')
            AND NOT EXISTS
                   (SELECT 'x'
                      FROM cascsi.cas_ib_recoveries r2
                     WHERE r2.original_recovery_id = r.recovery_id
                       AND r2.recovery_type IN ('REVERSAL', 'CREDIT'))
            AND NOT EXISTS
                   (SELECT 'x'
                      FROM csi.csi_i_extended_attribs ea_cr,
                           om.om_arp_values eav
                     WHERE ea_cr.attribute_code = 'CAS_RECOVERY_CREDIT_STATUS'
                       AND eav.attribute_id = ea_cr.attribute_id
                       AND eav.instance_id = r.instance_id
                       AND eav.attribute_value = 'YES')
         ORDER BY r.instance_id, pd.end_date;

      --
      d_recovery_period_start_date   gl_periods.start_date%TYPE;
      d_recovery_period_end_date     gl_periods.end_date%TYPE;
      n_recovery_period_year         gl_periods.period_year%TYPE;
      v_process_flag                 cascsi.cas_ib_recoveries.process_flag%TYPE;
      --
      -- numeric return code required for CAS_OM_UTL.
      n_return_code                  NUMBER;
      t_attributes_tbl               cas_om_utl.tt_ib_update_tbl;
      --
      v_message                      VARCHAR2(4000);
      v_return_code                  VARCHAR2(1);
      v_period_set_name              gl_periods.period_set_name%TYPE;
      n_recovery_id                  cas_ib_recoveries.recovery_id%TYPE;
      n_run_id                       cas_interface_logs.run_id%TYPE;
      -- Alert 202659 - n_wts_party_id no longer required
      --  n_wts_party_id                        hz_parties.party_id%TYPE;
      -- track previous instance ID and update CAS_RECOVERY_CREDIT_STATUS attribute when ID changes.
      n_prev_instance_id             csi_item_instances.instance_id%TYPE := 0;
      --
      n_error_count                  NUMBER := 0;
      -- number of records with a problem.
      n_total_count                  NUMBER := 0;
   -- total number of consumption records processed.
   --
   BEGIN
      --
      -- log start of recovery run
      --
      cas_log_batch_utl.prc_start_package(
         'CAS IB Recoveries',
         'CAS_IB_RECOVER',
         gc_version_no,
         gc_version_dt,
         c_procedure_name,
            ' recovery type=CREDIT recovery_period='
         || pv_recovery_period_in
         || ' gl_period='
         || pv_gl_period_in
         || ' set_of_books_id='
         || pn_set_of_books_id_in
         || ' trace='
         || pn_trace_flag_in
         || ' validate='
         || pn_validate_flag_in
         || ' customer_type='
         || pv_customer_type_in
      );
      --
      -- get current run_id (entered on each IB_recovery row).
      --
      n_run_id := cas_interface_log.fn_run_id;
      pn_run_id_out := n_run_id;

      --
      -- Alert 202659 - BCAS recoveries - move check for BPS party table to main procedure
      --
      -- get info re: set of books
      --
      cas_ib_utl.prc_select_set_of_books(pn_set_of_books_id_in,
                                         v_period_set_name,
                                         v_return_code,
                                         v_message);

      --
      IF (v_return_code > 0) THEN
         raise_application_error( -20000, 'Error retrieving set of books info for id=' || pn_set_of_books_id_in || ': ' || v_message);
      END IF;

      --
      -- validate GL period name.
      --
      IF (NOT fn_is_valid_period_name( v_period_set_name, pv_gl_period_in)) THEN
         raise_application_error( -20000, 'Invalid GL period name: ' || pv_gl_period_in);
      END IF;

      --
      -- get recovery period start/end dates
      --
      cas_ib_utl.prc_get_gl_period_dates(v_period_set_name,
                                         UPPER(pv_recovery_period_in),
                                         d_recovery_period_start_date,
                                         d_recovery_period_end_date,
                                         n_recovery_period_year,
                                         v_return_code,
                                         v_message);

      --
      IF (v_return_code > 0) THEN
         raise_application_error( -20000, 'Error retrieving period start/end dates for recovery period ' || pv_recovery_period_in || ': ' || v_message);
      END IF;

     --
     -- Loop through credit records to process credit recoveries.
     --
     <<instance_loop>>
      -- Alert 202659 - wts_party_id parameter no longer required
      FOR r_recovery IN cr_credit_recoveries(v_period_set_name) LOOP
         --
         n_total_count := n_total_count + 1;

         IF (pn_trace_flag_in = 1) THEN
            cas_interface_log.prc_log_trace( c_procedure_name, 'TRACE: Processing recovery_id=' || r_recovery.recovery_id || ' instance_id=' || r_recovery.instance_id || ' amount=' || r_recovery.amount);
         END IF;

         --
         -- get credit period year - compare with input recovery period year - flag previous fiscal items.
         --
         IF (r_recovery.period_year != n_recovery_period_year) THEN
            --
            -- log previous fiscal recovery record.
            --
            v_process_flag := 'F';
            --
            cas_interface_log.prc_log_info(
               c_procedure_name,
               'Previous fiscal period ' || r_recovery.recovery_period_name || ', flag=' || v_process_flag,
               'instance_id=' || r_recovery.instance_id || ' original recovery_id=' || r_recovery.recovery_id,
               r_recovery.instance_id,
               n_recovery_id
            );
         ELSE
            v_process_flag := 'I';
         END IF;

         --
         IF (pn_validate_flag_in = 0) THEN
            --
            -- get next recovery_id.
            --
            SELECT cas_ib_recovery_id_seq.NEXTVAL INTO n_recovery_id FROM DUAL;

            --
            -- insert recovery record.
            --
            BEGIN
               INSERT
                 INTO cas_ib_recoveries(recovery_id,
                                        org_id,
                                        run_id,
                                        set_of_books_id,
                                        gl_period_name,
                                        recovery_period_name,
                                        inventory_item_id,
                                        inv_master_organization_id,
                                        instance_id,
                                        instance_number,
                                        consumption_id,
                                        adjustment_id,
                                        quantity,
                                        price,
                                        item_uom,
                                        amount,
                                        recovery_type,
                                        expense_client,
                                        expense_responsibility,
                                        expense_service_line,
                                        expense_stob,
                                        expense_project,
                                        expense_ccid,
                                        default_expense_flag,
                                        recovery_client,
                                        recovery_responsibility,
                                        recovery_service_line,
                                        recovery_stob,
                                        recovery_project,
                                        owner_party_id,
                                        owner_party_account_id,
                                        tca_party_id,
                                        tca_account_id,
                                        tca_account_name,
                                        bill_to_site,
                                        bps_cost_centre,
                                        sda_party_id,
                                        sda_account_id,
                                        display_name,
                                        customer_class,
                                        colour,
                                        external_reference,
                                        order_po_number,
                                        last_oe_order_line_id,
                                        process_flag,
                                        created_by,
                                        creation_date,
                                        last_updated_by,
                                        last_updated_date,
                                        original_recovery_id)
               VALUES (n_recovery_id, r_recovery.org_id, n_run_id, r_recovery.set_of_books_id, UPPER(pv_gl_period_in),
                       r_recovery.recovery_period_name, r_recovery.inventory_item_id, r_recovery.inv_master_organization_id,
                       r_recovery.instance_id, r_recovery.instance_number, r_recovery.consumption_id, r_recovery.adjustment_id,
                       -r_recovery.quantity, r_recovery.price, r_recovery.item_uom, -r_recovery.amount, 'CREDIT',
                       r_recovery.expense_client, r_recovery.expense_responsibility, r_recovery.expense_service_line,
                       r_recovery.expense_stob, r_recovery.expense_project, r_recovery.expense_ccid, r_recovery.default_expense_flag,
                       r_recovery.recovery_client, r_recovery.recovery_responsibility, r_recovery.recovery_service_line,
                       r_recovery.recovery_stob, r_recovery.recovery_project, r_recovery.owner_party_id, r_recovery.owner_party_account_id,
                       r_recovery.tca_party_id, r_recovery.tca_account_id, r_recovery.tca_account_name, r_recovery.bill_to_site,
                       r_recovery.bps_cost_centre, r_recovery.sda_party_id, r_recovery.sda_account_id, r_recovery.display_name,
                       r_recovery.customer_class, r_recovery.colour, r_recovery.external_reference, r_recovery.order_po_number,
                       r_recovery.last_oe_order_line_id, v_process_flag, cas_common_utl.fn_get_user_id('BATCH'),
                       SYSDATE, cas_common_utl.fn_get_user_id('BATCH'), SYSDATE, r_recovery.recovery_id);
            --
            --
            EXCEPTION
               WHEN OTHERS THEN
                  cas_interface_log.prc_log_warning(
                     c_procedure_name,
                     SQLERRM,
                        'instance_id='
                     || r_recovery.instance_id
                     || ' recovery_period='
                     || r_recovery.recovery_period_name
                     || ' original recovery_id='
                     || r_recovery.recovery_id,
                     r_recovery.instance_id,
                     n_recovery_id
                  );
                  cas_log_batch_utl.prc_set_warning_on;
                  n_error_count := n_error_count + 1;
            END;

            --
            IF (pn_trace_flag_in = 1) THEN
               cas_interface_log.prc_log_trace(
                  c_procedure_name,
                  'Credit issued',
                  'instance_id=' || r_recovery.instance_id || ' original recovery_id=' || r_recovery.recovery_id,
                  r_recovery.instance_id,
                  n_recovery_id
               );
            END IF;

            --
            IF (r_recovery.instance_id <> n_prev_instance_id) THEN
               --
               -- initialize extended attribute update table (passed to CAS_OM_UTL.cas_update_ib_attributes).
               t_attributes_tbl(1).column_name := 'cas_recovery_credit_status'; -- V 8.2.
               t_attributes_tbl(1).update_value := 'YES';

               --
               BEGIN
                  -- update recovery_credits flag for this item instance.
                  cas_om_utl.cas_update_ib_attributes(r_recovery.instance_id,
                                                      r_recovery.object_version_number,
                                                      NULL, -- context not required when only updating extended attribute.
                                                      t_attributes_tbl,
                                                      n_return_code,
                                                      v_message);

                  --
                  IF (n_return_code > 0) THEN
                     cas_interface_log.prc_log_warning(
                        c_procedure_name,
                        'Error encountered when updating item instance Recovery Credit status attribute: ' || v_message,
                        NULL,
                        r_recovery.instance_id
                     );
                     cas_log_batch_utl.prc_set_warning_on;
                  ELSE
                     cas_interface_log.prc_log_info(c_procedure_name,
                                                    'Status updated',
                                                    NULL,
                                                    r_recovery.instance_id);
                  END IF;
               --
               EXCEPTION
                  WHEN OTHERS THEN
                     cas_interface_log.prc_log_warning(c_procedure_name,
                                                       'IB update unexpected error: ' || SQLERRM,
                                                       NULL,
                                                       r_recovery.instance_id,
                                                       n_recovery_id);
                     cas_log_batch_utl.prc_set_warning_on;
               END;

               --
               n_prev_instance_id := r_recovery.instance_id;
            --
            END IF; -- next instance_id.
         END IF; -- not validate.
      --
      END LOOP instance_loop;

      --
      cas_interface_log.prc_log_info( c_procedure_name, 'Rows processed: ' || TO_CHAR(n_total_count) || ' Errors: ' || TO_CHAR(n_error_count));
      --
      cas_log_batch_utl.prc_set_normal_end_of_package(c_procedure_name,
                                                      pv_return_code_out,
                                                      pv_message_out);
   --
   EXCEPTION
      WHEN OTHERS THEN
         cas_interface_log.prc_log_error( c_procedure_name, 'Credit recoveries unexpected error: ' || SQLERRM);
         cas_log_batch_utl.prc_set_error_on;
         cas_log_batch_utl.prc_set_error_end_of_package(c_procedure_name,
                                                        pv_return_code_out,
                                                        pv_message_out);
   END prc_process_credits;
   */
   /*
   --
   --***************************************************************************************************
   --* Procedure : prc_process_adjustments
   --* Purpose : Process adjustment recoveries.
   --* Parameters: pv_gl_period_in   - GL period to which recoveries are posted (e.g. MAY-08).
   --*  pn_set_of_books_id_in - set of books id (e.g. 16=BCGOV).
   --*  pn_run_id_out   - run id - generated by cas_interface_log package.
   --*  pv_return_code_out  - procedure return code ('0'=ok, '1'=warning, '2'=error).
   --*  pv_message_out   - optional output message.
   --*  pn_dflt_coding_flag_in  - optional input flag to use default coding if given coding is invalid.
   --*  pn_trace_flag_in  - optional input flag to enable tracing to cas_interface_logs.
   --* Called By :
   --***************************************************************************************************
   PROCEDURE prc_process_adjustments(pv_recovery_period_in  IN            gl_periods.period_name%TYPE,
                                     pv_gl_period_in        IN            gl_periods.period_name%TYPE,
                                     pn_set_of_books_id_in  IN            gl_sets_of_books.set_of_books_id%TYPE,
                                     pn_run_id_out             OUT NOCOPY cas_interface_logs.run_id%TYPE,
                                     pv_return_code_out        OUT NOCOPY VARCHAR2,
                                     pv_message_out            OUT NOCOPY VARCHAR2,
                                     pn_dflt_coding_flag_in IN            NUMBER,
                                     pn_trace_flag_in       IN            NUMBER,
                                     pv_customer_type_in    IN            VARCHAR2) IS
      --
      -- define constant for procedure name; used in calls to CAS_INTERFACE_LOG package.
      c_procedure_name   CONSTANT VARCHAR2(30) := 'prc_process_adjustments';
      --

      -- Alert # 191418
      n_cas_bps_cost_centre       NUMBER;

      -- cursor to loop through pending adjustments.
      -- Each pending adjustment record is first expanded into one record for each period in the period range.
      -- Alert 202659 - wts_party_id parameter no longer required
      CURSOR cr_adjustments IS
         SELECT adj.adjustment_id, adj.instance_id
           FROM cas_ib_adjustments adj,
                csi.csi_item_instances item_instance
          WHERE adj.recovery_status = 'PENDING'
            AND item_instance.instance_id = adj.instance_id
            AND ((pv_customer_type_in = 'B'
              AND item_instance.owner_party_id IN (SELECT key
                                                     FROM casint.cas_generic_table_details
                                                    WHERE category = 'CAS_BPS_PARTY_IDS'))
              OR (pv_customer_type_in = 'M'
              AND item_instance.owner_party_id NOT IN (SELECT key
                                                         FROM casint.cas_generic_table_details
                                                        WHERE category = 'CAS_BPS_PARTY_IDS'))
              OR pv_customer_type_in IS NULL);

      --
      -- cursor to loop through adjustment recovery records to generate recovery transactions.
      --
      CURSOR cr_adj_recoveries(cn_adjustment_id IN cas_ib_adjustments.adjustment_id%TYPE) IS
         SELECT adj.override_price,
                adjr.adj_recovery_id,
                adjr.recovery_period_name,
                item_instance.instance_id,
                item_instance.instance_number,
                item_instance.object_version_number,
                item_instance.inventory_item_id,
                item_instance.inv_master_organization_id,
                item_instance.last_vld_organization_id,
                item_instance.external_reference,
                item_instance.last_oe_order_line_id,
                --                cas_ib_utl.fn_select_extended_attribute( item_instance.instance_id, n_cas_bps_cost_centre) bps_cost_centre, -- Alert # 191418
                (SELECT MAX(attribute_value)
                   FROM om.om_arp_values
                  WHERE instance_id = item_instance.instance_id
                    AND attribute_id = n_cas_bps_cost_centre)
                   bps_cost_centre,
                adj.adjustment_quantity,
                item_instance.unit_of_measure,
                item_instance.attribute1 expense_client,
                item_instance.attribute2 expense_responsibility,
                item_instance.attribute3 expense_service_line,
                item_instance.attribute4 expense_stob,
                item_instance.attribute5 expense_project,
                item_instance.attribute6 expense_ccid,
                item_instance.owner_party_id,
                item_instance.owner_party_account_id,
                item_instance.attribute7 description,
                item_instance.attribute10 istore_org,
                item_instance.attribute12 recovery_frequency,
                item_instance.attribute13 order_price
           FROM cas_ib_adjustments adj,
                cas_ib_adj_recoveries adjr,
                csi_item_instances item_instance
          WHERE adj.adjustment_id = cn_adjustment_id
            AND adjr.adjustment_id = adj.adjustment_id
            AND item_instance.instance_id = adj.instance_id
            AND adjr.recovery_id IS NULL -- ignore if already processed.  This would only occur when restarting after aborted run.  -- V 9.0.
         ORDER BY adjr.adj_recovery_id;

      --
      v_period_set_name           gl_periods.period_set_name%TYPE;
      n_recovery_period_year      gl_periods.period_year%TYPE;
      n_adj_period_year           gl_periods.period_year%TYPE;
      v_process_flag              cascsi.cas_ib_recoveries.process_flag%TYPE;
      n_recovery_id               cas_ib_recoveries.recovery_id%TYPE;
      v_default_expense_flag      VARCHAR2(1) := 'N';
      v_return_code               VARCHAR2(1);
      v_message                   VARCHAR2(4000);
      v_customer_class_code       hz_cust_accounts.customer_class_code%TYPE;
      n_account_id                hz_cust_accounts.cust_account_id%TYPE;
      n_sda_account_id            hz_cust_accounts.cust_account_id%TYPE;
      v_account_number            hz_cust_accounts.account_number%TYPE;
      v_account_name              hz_cust_accounts.account_name%TYPE;
      v_ministry_code             hz_cust_accounts.account_name%TYPE;
      -- WENDM - Feb 15 new fundiing model.START
      v_recovery_flag             VARCHAR2(1); -- Recover Y or N
      -- WENDM - Feb 15 new fundiing model.END
      n_party_id                  hz_cust_accounts.party_id%TYPE;
      n_sda_party_id              hz_cust_accounts.party_id%TYPE;
      n_bill_to_address           csi_ip_accounts.bill_to_address%TYPE;
      --
      v_recovery_client           csi_item_instances.attribute1%TYPE;
      v_recovery_resp             csi_item_instances.attribute2%TYPE;
      v_recovery_service          csi_item_instances.attribute3%TYPE;
      v_recovery_stob             csi_item_instances.attribute4%TYPE;
      v_save_stob                 csi_item_instances.attribute4%TYPE;
      v_recovery_project          csi_item_instances.attribute5%TYPE;
      --
      v_expense_client            csi_item_instances.attribute1%TYPE;
      v_expense_resp              csi_item_instances.attribute2%TYPE;
      v_expense_service           csi_item_instances.attribute3%TYPE;
      v_expense_stob              csi_item_instances.attribute4%TYPE;
      v_expense_project           csi_item_instances.attribute5%TYPE;
      v_expense_ccid              csi_item_instances.attribute6%TYPE;
      v_po_number                 oe_order_headers_all.cust_po_number%TYPE;
      --
      v_recovery_price_source     mtl_descr_element_values.element_value%TYPE;
      v_colour                    mtl_descr_element_values.element_value%TYPE;
      v_reporting_uom             mtl_descr_element_values.element_value%TYPE;
      v_item_name                 mtl_system_items_b.segment1%TYPE;
      v_item_uom                  mtl_system_items_b.primary_uom_code%TYPE;
      n_prev_inventory_item_id    mtl_system_items_b.inventory_item_id%TYPE := 0;
      n_price                     NUMBER;
      n_run_id                    cas_interface_logs.run_id%TYPE;
      -- Alert 202659 - n_wts_party_id no longer required
      --  n_wts_party_id                        hz_parties.party_id%TYPE;
      --
      -- The flags below indicate error conditions with item or item_instance that
      -- would prevent the recovery transaction from being processed successfully.
      -- Used when setting the transaction process_flag column.
      --
      v_error_flag                VARCHAR2(1); -- problem with item (Y/N).
      n_error_count               NUMBER := 0;
      -- number of records with a problem.
      n_adj_error_count           NUMBER := 0; -- count of errors for adjustment being processed.
      n_adj_count                 NUMBER := 0;
      -- number of adjustment records processed.
      n_adjr_count                NUMBER := 0;
   -- number of adjustment recovery records processed.
   --
   BEGIN
      --

      n_cas_bps_cost_centre := cas_ib_utl.fn_get_attribute_id('CAS_BPS_COST_CENTRE');

      -- log start of recovery run
      --
      cas_log_batch_utl.prc_start_package(
         'CAS IB Recoveries',
         'CAS_IB_RECOVER',
         gc_version_no,
         gc_version_dt,
         c_procedure_name,
            'type=ADJ '
         || ' recovery_period='
         || pv_recovery_period_in
         || ' gl_pd='
         || pv_gl_period_in
         || ' sob_id='
         || pn_set_of_books_id_in
         || ' trace='
         || pn_trace_flag_in
         || ' cust_type='
         || pv_customer_type_in --     || CASE
      --       WHEN (pn_owner_party_id_in IS NOT NULL) THEN ' owner_party_id=' || pn_owner_party_id_in
      --      END
      --       || CASE
      --       WHEN (pn_inventory_item_id_in IS NOT NULL) THEN ' inventory_item_id=' || pn_inventory_item_id_in
      --      END
      );
      --
      -- get current run_id (entered on each IB_recovery row).
      --
      n_run_id := cas_interface_log.fn_run_id;
      pn_run_id_out := n_run_id;

      --
      -- Alert 202659 - BCAS recoveries - move check for BPS party table to main procedure
      --
      -- get period set name from set of books.
      --
      cas_ib_utl.prc_select_set_of_books(pn_set_of_books_id_in,
                                         v_period_set_name,
                                         v_return_code,
                                         v_message);

      --
      IF (v_return_code > 0) THEN
         raise_application_error( -20000, 'Error retrieving set of books info for id=' || pn_set_of_books_id_in || ': ' || v_message);
      END IF;

      --
      -- validate GL period name.
      --
      IF (NOT fn_is_valid_period_name( v_period_set_name, pv_gl_period_in)) THEN
         raise_application_error( -20000, 'Invalid GL period name: ' || pv_gl_period_in);
      END IF;

      --
      -- get recovery period year.
      --
      SELECT period_year
        INTO n_recovery_period_year
        FROM gl.gl_periods glp
       WHERE glp.period_set_name = v_period_set_name
         AND glp.period_name = pv_recovery_period_in;

      --
      -- log period year
      --
      cas_interface_log.prc_log_info(c_procedure_name,
                                     'Recovery period year: ' || TO_CHAR(n_recovery_period_year),
                                     'Recovery period name=' || pv_recovery_period_in,
                                     NULL,
                                     NULL);

     --
     -- Loop through adjustment records to process recoveries.
     --
     <<adjustment_loop>>
      -- Alert 202659 - wts_party_id parameter no longer required in call to cr_adjustments cursor
      FOR r_adj IN cr_adjustments LOOP
         --
         BEGIN
            --
            n_adj_error_count := 0; -- initialize error counter for current adjustment.
            n_adj_count := n_adj_count + 1;
            --
            -- expand adjustment period range. This will insert one row per adjustment period into cascsi.cas_ib_adj_recoveries.
            prc_expand_adjustment_periods(r_adj.adjustment_id,
                                          pn_set_of_books_id_in,
                                          v_return_code,
                                          v_message);

            --
            IF (v_return_code > 0) THEN
               -- log failure to expand periods.
               cas_log_batch_utl.prc_set_warning_on;
               cas_interface_log.prc_log_warning(c_procedure_name,
                                                 'Failed to expand period range: ' || v_message,
                                                 'adjustment_id= ' || r_adj.adjustment_id,
                                                 r_adj.adjustment_id);
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
               n_adj_error_count := n_adj_error_count + 1;
            ELSE
               --
               -- now loop through expanded periods for current adjustment.
               --
               FOR r_recovery IN cr_adj_recoveries(r_adj.adjustment_id) LOOP
                  n_adjr_count := n_adjr_count + 1;
                  --
                  v_error_flag := 'N'; -- initialize item instance error flag.
                  n_price := 0; -- initialize price

                  --
                  -- get name of current item
                  --
                  SELECT segment1 item_name, primary_uom_code
                    INTO v_item_name, v_item_uom
                    FROM mtl_system_items_b
                   WHERE inventory_item_id = r_recovery.inventory_item_id
                     AND organization_id = r_recovery.inv_master_organization_id;

                  --
                  -- get recovery price source for current item (i.e. ITEM or ORDER).
                  --
                  v_recovery_price_source := cas_ib_utl.fn_select_catalog_element( r_recovery.inventory_item_id, 'Recovery Price Source');

                  --
                  IF (v_recovery_price_source IS NULL) THEN
                     -- log missing recovery price source
                     cas_log_batch_utl.prc_set_warning_on;
                     cas_interface_log.prc_log_warning(
                        c_procedure_name,
                        'Item recovery price source is missing or blank; defaulted to ITEM ',
                           'instance_id='
                        || r_recovery.instance_id
                        || ' inventory_item_id='
                        || r_recovery.inventory_item_id,
                        r_recovery.adj_recovery_id
                     );
                  END IF;

                  --
                  v_colour := cas_ib_utl.fn_select_catalog_element( r_recovery.inventory_item_id, 'Colour');

                  --
                  IF (v_colour IS NULL) THEN
                     -- log missing colour
                     cas_log_batch_utl.prc_set_warning_on;
                     cas_interface_log.prc_log_warning(
                        c_procedure_name,
                        'Item colour is missing or blank.',
                           'instance_id='
                        || r_recovery.instance_id
                        || 'inventory_item_id='
                        || r_recovery.inventory_item_id,
                        r_recovery.adj_recovery_id
                     );
                  --
                  END IF;

                  --
                  IF (pn_trace_flag_in = 1) THEN
                     cas_interface_log.prc_log_trace(
                        c_procedure_name,
                           v_item_name
                        || ' Price Source='
                        || v_recovery_price_source
                        || ' UOM='
                        || v_reporting_uom
                        || ' Colour='
                        || v_colour,
                           'instance_id='
                        || r_recovery.instance_id
                        || ' inventory_item_id='
                        || r_recovery.inventory_item_id,
                        r_recovery.adj_recovery_id
                     );
                  END IF;

                  --
                  -- get recovery GL coding for current item
                  --
                  cas_ib_utl.prc_select_recovery_coding(r_recovery.inventory_item_id,
                                                        v_recovery_client,
                                                        v_recovery_resp,
                                                        v_recovery_service,
                                                        v_recovery_stob,
                                                        v_recovery_project,
                                                        v_return_code,
                                                        v_message);

                  --
                  IF (v_return_code > 0
                   OR v_recovery_client IS NULL
                   OR v_recovery_resp IS NULL
                   OR v_recovery_service IS NULL
                   OR v_recovery_stob IS NULL
                   OR v_recovery_project IS NULL) THEN
                     -- log recovery coding error.
                     cas_interface_log.prc_log_warning(
                        c_procedure_name,
                        'Recovery coding error: ' || v_message,
                           'instance_id='
                        || r_recovery.instance_id
                        || ' inventory_item_id='
                        || r_recovery.inventory_item_id,
                        r_recovery.adj_recovery_id
                     );
                     cas_log_batch_utl.prc_set_warning_on;
                     v_error_flag := 'Y';
                     n_error_count := n_error_count + 1;
                     n_adj_error_count := n_adj_error_count + 1;
                  END IF;

                  --
                  -- get customer info
                  --
                  cas_ib_utl.prc_select_customer_info(r_recovery.instance_id,
                                                      v_customer_class_code,
                                                      n_account_id,
                                                      v_account_number,
                                                      v_account_name,
                                                      n_party_id,
                                                      n_bill_to_address,
                                                      v_return_code,
                                                      v_message);

                  --
                  --
                  IF (v_return_code > 0) THEN
                     -- log failure to retrieve customer info.
                     cas_log_batch_utl.prc_set_warning_on;
                     cas_interface_log.prc_log_warning(
                        c_procedure_name,
                        'Failed to retrieve customer class and/or TCA account/party info: ' || v_message,
                           'instance_id= '
                        || r_recovery.instance_id
                        || ' TCA Account ID='
                        || TO_CHAR(n_account_id)
                        || ' customer class='
                        || v_customer_class_code,
                        r_recovery.adj_recovery_id
                     );
                     v_error_flag := 'Y';
                     n_error_count := n_error_count + 1;
                     n_adj_error_count := n_adj_error_count + 1;
                     --
                     v_ministry_code := '';
                  --
                  ELSE
                     -- check customer class consistent with customer type input parameter.
                     -- Alert 202659 - use new function fn_isbps() to determine if party is BPS
                     IF (fn_isbps(r_recovery.owner_party_id) = 1
                     AND v_customer_class_code NOT LIKE 'PUBLIC_SECTOR%'
                      OR fn_isbps(r_recovery.owner_party_id) = 0
                     AND v_customer_class_code NOT LIKE 'MINISTRY%') THEN
                        -- log inconsistency between owner_party and cust_class.
                        cas_log_batch_utl.prc_set_warning_on;
                        cas_interface_log.prc_log_warning(
                           c_procedure_name,
                              'Requested customer type is '
                           || pv_customer_type_in
                           || ' but customer class is: '
                           || v_customer_class_code,
                           'instance_id= ' || r_recovery.instance_id || ' TCA Account ID=' || TO_CHAR(n_account_id),
                           r_recovery.adj_recovery_id
                        );
                        --
                        v_error_flag := 'Y';
                        n_error_count := n_error_count + 1;
                        n_adj_error_count := n_adj_error_count + 1;
                     --
                     END IF;

                     -- parse ministry code from TCA name. Get the string between the two dashes.
                     -- This is used to check for 'WTS' when setting the recovery process flag.
                     v_ministry_code := SUBSTR(v_account_name,
                                               5,
                                               INSTR(v_account_name,
                                               '-',
                                               5) - 5);

                     ---------------------------------------------------------------------------------------------
                     -- WENDM get recovery flag using cust_account_id, cust_account_number and cust_account name
                     -- returned from the above lookup. Return upper case Y or N.
                     -- Colour BLUE is hardcoded for now but can be putin cas_generci tables.
                     -- All records with PROCESS_FLAG of W in cas_ib_recoveries will be ignored by recovery JV process.
                     IF v_ministry_code = 'WTS' THEN
                        v_recovery_flag := 'W';
                     ELSIF (SUBSTR(v_customer_class_code,
                                   1,
                                   8) = 'MINISTRY') THEN
                        v_recovery_flag := fn_get_recovery_flag(n_account_id,
                                                                v_account_number,
                                                                v_account_name,
                                                                v_colour);
                     ELSE
                        v_recovery_flag := 'I';
                     END IF;

                     --
                     IF (SUBSTR(v_customer_class_code,
                                1,
                                8) != 'MINISTRY') THEN
                        -- default SDA account ID to owner_party account ID for non-ministry customers.
                        n_sda_account_id := r_recovery.owner_party_account_id;
                        n_sda_party_id := r_recovery.owner_party_id;

                        --
                        -- check for PUBLIC_SECTOR_INVOICED customer type and replace recovery stob if necessary.
                        IF (v_customer_class_code = 'PUBLIC_SECTOR_INVOICED') THEN
                           cas_ib_utl.prc_get_bps_recoveries_stob(r_recovery.instance_id,
                                                                  v_recovery_stob,
                                                                  v_return_code,
                                                                  v_message);

                           --
                           IF (v_return_code > '0') THEN
                              cas_log_batch_utl.prc_set_warning_on;
                              cas_interface_log.prc_log_warning(
                                 c_procedure_name,
                                 'Failed to find BPS recovery STOB for BPS customer: ' || v_message,
                                    'instance_id= '
                                 || r_recovery.instance_id
                                 || ' customer class='
                                 || v_customer_class_code,
                                 r_recovery.adj_recovery_id
                              );
                              --
                              -- default recovery stob if not found.
                              v_recovery_stob := fn_get_default_recovery_stob(v_customer_class_code);
                           END IF;
                        END IF;
                     ELSE
                        --
                        -- get SDA party and account for TCA account.
                        --
                        cas_ib_utl.prc_get_sda_ministry(n_account_id,
                                                        n_sda_party_id,
                                                        n_sda_account_id,
                                                        v_return_code,
                                                        v_message);

                        --
                        IF (v_return_code > 0) THEN
                           -- log failure to retrieve SDA account.
                           --   v_error_flag := 'Y';
                           cas_log_batch_utl.prc_set_warning_on;
                           cas_interface_log.prc_log_warning(
                              c_procedure_name,
                              'Failed to retrieve SDA account: ' || v_message,
                              'instance_id= ' || r_recovery.instance_id || ' TCA account ID=' || n_account_id,
                              r_recovery.adj_recovery_id
                           );
                        --    n_error_count := n_error_count + 1;
                        END IF;
                     END IF;
                  --
                  END IF;

                  --
                  -- Extrace GL coding from item instance.
                  -- It may change if it's invalid.
                  v_expense_client := r_recovery.expense_client;
                  v_expense_resp := r_recovery.expense_responsibility;
                  v_expense_service := r_recovery.expense_service_line;
                  v_expense_stob := r_recovery.expense_stob;
                  v_expense_project := r_recovery.expense_project;
                  v_expense_ccid := r_recovery.expense_ccid;
                  --
                  prc_get_expense_coding(r_recovery.istore_org,
                                         pn_dflt_coding_flag_in,
                                         n_account_id,
                                         v_expense_client,
                                         v_expense_resp,
                                         v_expense_service,
                                         v_expense_stob,
                                         v_expense_project,
                                         v_expense_ccid,
                                         v_default_expense_flag,
                                         v_return_code,
                                         v_message);

                  --
                  IF (v_expense_ccid IS NULL) THEN
                     -- reset client, resp, svc, proj, which could now be null.
                     v_expense_client := r_recovery.expense_client;
                     v_expense_resp := r_recovery.expense_responsibility;
                     v_expense_service := r_recovery.expense_service_line;
                     v_expense_project := r_recovery.expense_project;

                     --
                     IF (v_customer_class_code != 'PUBLIC_SECTOR_INVOICED') THEN
                        -- log invalid code combination for non-invoiced records.
                        cas_log_batch_utl.prc_set_warning_on;
                        cas_interface_log.prc_log_warning(
                           c_procedure_name,
                              'Invalid expense GL code combination: '
                           || v_message
                           || ' '
                           || v_expense_client
                           || '.'
                           || v_expense_resp
                           || '.'
                           || v_expense_service
                           || '.'
                           || v_expense_stob
                           || '.'
                           || v_expense_project
                           || ' default coding='
                           || v_default_expense_flag,
                           'instance_id= ' || r_recovery.instance_id,
                           r_recovery.adj_recovery_id
                        );
                        v_error_flag := 'Y';
                        n_error_count := n_error_count + 1;
                        n_adj_error_count := n_adj_error_count + 1;
                     END IF;
                  --
                  END IF;

                  --
                  v_po_number := fn_get_po_number(r_recovery.last_oe_order_line_id);

                  --
                  -- write trace record to log if trace flag is on.
                  --
                  IF (pn_trace_flag_in = 1) THEN
                     cas_interface_log.prc_log_trace(
                        c_procedure_name,
                           'expense coding='
                        || r_recovery.expense_client
                        || '.'
                        || r_recovery.expense_responsibility
                        || '.'
                        || r_recovery.expense_service_line
                        || '.'
                        || r_recovery.expense_stob
                        || '.'
                        || r_recovery.expense_project
                        || ':'
                        || r_recovery.expense_ccid,
                        'instance_id= ' || r_recovery.instance_id,
                        r_recovery.adj_recovery_id
                     );
                  END IF;

                  --
                  IF (pn_trace_flag_in = 1) THEN
                     cas_interface_log.prc_log_trace(
                        c_procedure_name,
                           'recovery coding='
                        || v_recovery_client
                        || '.'
                        || v_recovery_resp
                        || '.'
                        || v_recovery_service
                        || '.'
                        || v_recovery_stob
                        || '.'
                        || v_recovery_project
                        || ' cust class='
                        || v_customer_class_code,
                        'instance_id= ' || r_recovery.instance_id,
                        r_recovery.adj_recovery_id
                     );
                  --
                  END IF;

                  --
                  --
                  -- get item price
                  --
                  IF (r_recovery.override_price IS NOT NULL) THEN
                     n_price := r_recovery.override_price;
                     cas_interface_log.prc_log_info(c_procedure_name,
                                                    'Price override: ' || TO_CHAR(n_price),
                                                    'instance_id=' || r_recovery.instance_id,
                                                    r_recovery.adj_recovery_id);
                  --
                  ELSIF (v_recovery_price_source = 'ORDER') THEN
                     n_price := TO_NUMBER(NVL(r_recovery.order_price, '0'));

                     -- log warning if order price is 0.
                     IF (n_price = 0) THEN
                        cas_interface_log.prc_log_warning(c_procedure_name,
                                                          'Order price is zero.',
                                                          'instance_id=' || r_recovery.instance_id,
                                                          r_recovery.adj_recovery_id);
                     END IF;
                  ELSE
                     -- v_recovery_price_source = 'ITEM'.
                     --
                     cas_ib_utl.prc_get_item_price(r_recovery.inventory_item_id,
                                                   v_customer_class_code,
                                                   r_recovery.recovery_period_name,
                                                   v_period_set_name,
                                                   n_price,
                                                   v_return_code,
                                                   v_message);

                     --
                     IF (v_return_code > 0
                     AND v_customer_class_code IS NOT NULL) THEN
                        cas_interface_log.prc_log_warning(
                           c_procedure_name,
                           'Item price error: ' || v_message,
                              'instance_id='
                           || r_recovery.instance_id
                           || ' inventory_item_id='
                           || r_recovery.inventory_item_id
                           || ' customer_class_code='
                           || v_customer_class_code
                           || ' period='
                           || r_recovery.recovery_period_name,
                           r_recovery.adj_recovery_id
                        );
                        cas_log_batch_utl.prc_set_warning_on;
                        v_error_flag := 'Y';
                        n_error_count := n_error_count + 1;
                        n_adj_error_count := n_adj_error_count + 1;
                        n_price := 0;
                     END IF;
                  END IF;

                  --
                  -- get next recovery_id.
                  --
                  SELECT cas_ib_recovery_id_seq.NEXTVAL INTO n_recovery_id FROM DUAL;

                  --
                  -- get adjustment period year.
                  --
                  SELECT period_year
                    INTO n_adj_period_year
                    FROM gl.gl_periods glp
                   WHERE glp.period_set_name = v_period_set_name
                     AND glp.period_name = r_recovery.recovery_period_name;

                  --

                  IF (n_adj_period_year != n_recovery_period_year) THEN -- V7.
                     --
                     -- log previous fiscal recovery record.
                     --
                     ---------------------------------------------------------------------------------------------
                     -- WENDM modified decode and added recovery flag
                     SELECT DECODE(
                               v_error_flag,
                               'Y', 'E',
                               DECODE(
                                  v_ministry_code,
                                  'WTS', 'W',
                                  DECODE(v_recovery_flag,
                                         'W', 'W',
                                         DECODE(SIGN(n_recovery_period_year - n_adj_period_year), 0, 'I', 'F'))
                               )
                            )
                       INTO v_process_flag
                       FROM DUAL;

                     --
                     cas_interface_log.prc_log_info(
                        c_procedure_name,
                        'Previous fiscal period ' || r_recovery.recovery_period_name || ', flag=' || v_process_flag,
                           'instance_id='
                        || r_recovery.instance_id
                        || ' inventory_item_id='
                        || r_recovery.inventory_item_id,
                        r_recovery.adj_recovery_id,
                        n_recovery_id
                     );
                  END IF;

                  --
                  -- insert recovery record.
                  --
                  BEGIN
                     INSERT
                       INTO cas_ib_recoveries(recovery_id,
                                              org_id,
                                              run_id,
                                              set_of_books_id,
                                              gl_period_name,
                                              recovery_period_name,
                                              inventory_item_id,
                                              inv_master_organization_id,
                                              instance_id,
                                              instance_number,
                                              adjustment_id,
                                              quantity,
                                              price,
                                              item_uom,
                                              amount,
                                              recovery_type,
                                              expense_client,
                                              expense_responsibility,
                                              expense_service_line,
                                              expense_stob,
                                              expense_project,
                                              expense_ccid,
                                              default_expense_flag,
                                              recovery_client,
                                              recovery_responsibility,
                                              recovery_service_line,
                                              recovery_stob,
                                              recovery_project,
                                              owner_party_id,
                                              owner_party_account_id,
                                              tca_party_id,
                                              tca_account_id,
                                              tca_account_name,
                                              bill_to_site,
                                              bps_cost_centre,
                                              sda_party_id,
                                              sda_account_id,
                                              description,
                                              customer_class,
                                              colour,
                                              external_reference,
                                              order_po_number,
                                              last_oe_order_line_id,
                                              process_flag,
                                              created_by,
                                              creation_date,
                                              last_updated_by,
                                              last_updated_date)
                     VALUES (n_recovery_id,
                             NVL(r_recovery.last_vld_organization_id, r_recovery.inv_master_organization_id), n_run_id,
                             pn_set_of_books_id_in, UPPER(pv_gl_period_in), r_recovery.recovery_period_name, r_recovery.inventory_item_id,
                             r_recovery.inv_master_organization_id, r_recovery.instance_id, r_recovery.instance_number,
                             r_recovery.adj_recovery_id, r_recovery.adjustment_quantity, n_price, v_item_uom, ROUND( r_recovery.adjustment_quantity * n_price, 2),
                             'ADJUSTMENT', v_expense_client, v_expense_resp, v_expense_service, v_expense_stob,
                             v_expense_project, v_expense_ccid, v_default_expense_flag, v_recovery_client,
                             v_recovery_resp, v_recovery_service, v_recovery_stob, v_recovery_project, r_recovery.owner_party_id,
                             r_recovery.owner_party_account_id, n_party_id, n_account_id, v_account_name,
                             n_bill_to_address, r_recovery.bps_cost_centre,
                             NVL(n_sda_party_id, r_recovery.owner_party_id),
                             NVL(n_sda_account_id, r_recovery.owner_party_account_id), r_recovery.description,
                             v_customer_class_code, v_colour, r_recovery.external_reference, v_po_number, r_recovery.last_oe_order_line_id,
                             --    DECODE (v_error_flag, 'Y', 'E', DECODE (v_ministry_code, 'WTS', 'W', 'I') ),
                             -- WENDM added decode recovery flag on FEB 16, 2010.
                             DECODE(v_error_flag, 'Y', 'E', DECODE(v_ministry_code, 'WTS', 'W', DECODE(v_recovery_flag, 'W', 'W', DECODE(SIGN(n_recovery_period_year - n_adj_period_year), 0, 'I', 'F')))),
                             cas_common_utl.fn_get_user_id('BATCH'), SYSDATE, cas_common_utl.fn_get_user_id('BATCH'),
                             SYSDATE);

                     --
                     -- update adjustment record with recovery_id.
                     --
                     UPDATE cas_ib_adj_recoveries
                        SET recovery_id = n_recovery_id,
                            last_updated_by = cas_common_utl.fn_get_user_id('BATCH'),
                            last_update_date = SYSDATE
                      WHERE adj_recovery_id = r_recovery.adj_recovery_id;
                  --
                  EXCEPTION
                     WHEN OTHERS THEN
                        cas_interface_log.prc_log_warning(
                           c_procedure_name,
                           SQLERRM,
                              'instance_id='
                           || r_recovery.instance_id
                           || ' recovery_period='
                           || r_recovery.recovery_period_name,
                           r_recovery.adj_recovery_id
                        );
                        cas_log_batch_utl.prc_set_warning_on;
                        v_error_flag := 'Y';
                        n_error_count := n_error_count + 1;
                        n_adj_error_count := n_adj_error_count + 1;
                  END;
               --
               END LOOP;

               --
               -- update adjustment record status if no errors occurred while processing current adjustment.
               -- V 9.0.
               IF (n_adj_error_count = 0) THEN
                  --
                  UPDATE cas_ib_adjustments
                     SET recovery_status = 'PROCESSED',
                         last_updated_by = cas_common_utl.fn_get_user_id('BATCH'),
                         last_update_date = SYSDATE
                   WHERE adjustment_id = r_adj.adjustment_id;
               --
               END IF; -- no error for current adjustment.
            --
            END IF; -- periods expanded ok.
         --
         EXCEPTION
            WHEN OTHERS THEN
               -- log error and continue to next adjustment.
               cas_interface_log.prc_log_warning(
                  c_procedure_name,
                  SQLERRM,
                  'instance_id=' || r_adj.instance_id || ' adjustment_id=' || r_adj.adjustment_id,
                  r_adj.adjustment_id
               );
               cas_log_batch_utl.prc_set_warning_on;
               v_error_flag := 'Y';
               n_error_count := n_error_count + 1;
         END;
      --
      END LOOP adjustment_loop;

      --
      cas_interface_log.prc_log_info( c_procedure_name, 'Adjustment headers processed: ' || TO_CHAR(n_adj_count));
      cas_interface_log.prc_log_info( c_procedure_name, 'Adjustment details processed: ' || TO_CHAR(n_adjr_count));
      cas_interface_log.prc_log_info( c_procedure_name, 'Errors: ' || TO_CHAR(n_error_count));
      --
      cas_log_batch_utl.prc_set_normal_end_of_package(c_procedure_name,
                                                      pv_return_code_out,
                                                      pv_message_out);
   --
   EXCEPTION
      WHEN OTHERS THEN
         cas_interface_log.prc_log_error( c_procedure_name, 'Adjustment recoveries unexpected error: ' || SQLERRM);
         cas_log_batch_utl.prc_set_error_on;
         cas_log_batch_utl.prc_set_error_end_of_package(c_procedure_name,
                                                        pv_return_code_out,
                                                        pv_message_out);
   END prc_process_adjustments;
*/
   --
   --***************************************************************************************************
   --* Procedure : prc_process_recoveries
   --* Purpose : Process recoveries for given recovery type and recovery fiscal period.
   --* Parameters: pv_recovery_type_in  - type of recovery (e.g. COMMON, ONE TIME, MONTHLY).
   --*  pv_recovery_period_in - period for which recoveries are generated (e.g. APR-08).
   --*  pv_gl_period_in   - GL period to which recoveries are posted (e.g. MAY-08).
   --*  pn_set_of_books_id_in - set of books id (e.g. 16=BCGOV).
   --*  pn_run_id_out   - run id - generated by cas_interface_log package.
   --*  pv_return_code_out  - procedure return code ('0'=ok, '1'=warning, '2'=error).
   --*  pv_message_out   - optional output message.
   --*  pn_dflt_coding_flag_in  - optional input flag to use default coding if given coding is invalid.
   --*  pn_trace_flag_in  - optional input flag to enable tracing to cas_interface_logs.
   --*  pn_validate_flag_in   - optional flag to run validation checks only.
   --*  pv_customer_type_in   - optional customer type  (M=Ministry, B=BPS, null=both).
   --*  pn_owner_party_id_in   - optional owner_party_id to limit rows for testing.
   --*  pn_seof_rk_in  - optional pn_seof_rk_in to limit rows for testing.
   --* Called By :
   --***************************************************************************************************
   PROCEDURE prc_process_recoveries(
      pv_recovery_type_in     IN            om_generic_table_details.key%TYPE,
      pv_recovery_period_in   IN            om_fin_periods.period_name%TYPE,
      pv_gl_period_in         IN            om_fin_periods.period_name%TYPE,
      pn_set_of_books_id_in   IN            om_fin_sets_of_books.set_of_books_id%TYPE,
      pn_run_id_out              OUT NOCOPY om_interface_logs.run_id%TYPE,
      pv_return_code_out         OUT NOCOPY VARCHAR2,
      pv_message_out             OUT NOCOPY VARCHAR2,
      pn_dflt_coding_flag_in  IN            NUMBER DEFAULT 1,
      -- use default coding?
      pn_trace_flag_in        IN            NUMBER DEFAULT 0,
      pn_validate_flag_in     IN            NUMBER DEFAULT 0,
      pv_customer_type_in     IN            VARCHAR2 DEFAULT NULL,
      pn_owner_party_id_in    IN            om_assets.owner_party_id%TYPE DEFAULT NULL,
      pn_seof_rk_in IN            om_assets.seof_rk%TYPE DEFAULT NULL   
   ) IS
      --
      -- define constant for procedure name; used in calls to CAS_INTERFACE_LOG package.
      c_procedure_name   CONSTANT VARCHAR2(30) := 'prc_process_recoveries';
      n_bps_count                 NUMBER;
      n_run_id                    om_interface_logs.run_id%TYPE;
   --
   BEGIN
      -- Alert 202659
      -- Determine if the given party_id is a BPS party.
      -- Raise error if the CAS_BPS_PARTY_IDS generic table has not been configured.
      --

      SELECT COUNT(*)
        INTO n_bps_count
        FROM om.om_generic_table_details
       WHERE category = 'CAS_BPS_PARTY_IDS';

      IF (n_bps_count = 0) THEN
         -- call prc_start_package() to get a run_id for the log message
         om_log_batch_utl.prc_start_package(
            'OM Recoveries',
            'OM_RECOVER',
            gc_version_no,
            gc_version_dt,
            c_procedure_name,
               ' recovery type='
            || pv_recovery_type_in
            || ' recovery_period='
            || pv_recovery_period_in
            || ' gl_period='
            || pv_gl_period_in
            || ' set_of_books_id='
            || pn_set_of_books_id_in
            || ' trace='
            || pn_trace_flag_in
            || ' validate='
            || pn_validate_flag_in
            || ' customer_type='
            || pv_customer_type_in
            || ' owner_party_id='
            || pn_owner_party_id_in
            || ' seof_rk='
            || pn_seof_rk_in
         );
         --
         n_run_id := om_interface_log.fn_run_id;
         pn_run_id_out := n_run_id;
         --
         raise_application_error( -20000, 'om generic table CAS_BPS_PARTY_IDS is not configured.');
      END IF;

      --
     /* CASE pv_recovery_type_in
         WHEN 'CGI CONS' THEN
            prc_process_consumption(pv_recovery_period_in,
                                    pv_gl_period_in,
                                    pn_set_of_books_id_in,
                                    pn_run_id_out,
                                    pv_return_code_out,
                                    pv_message_out,
                                    pn_dflt_coding_flag_in,
                                    pn_trace_flag_in,
                                    pn_validate_flag_in,
                                    pv_customer_type_in,
                                    pn_owner_party_id_in -- pn_inventory_item_id_in
                                                        );
         WHEN 'ADJ' THEN
            prc_process_adjustments(pv_recovery_period_in,
                                    pv_gl_period_in,
                                    pn_set_of_books_id_in,
                                    pn_run_id_out,
                                    pv_return_code_out,
                                    pv_message_out,
                                    pn_dflt_coding_flag_in,
                                    pn_trace_flag_in,
                                    pv_customer_type_in --      pn_owner_party_id_in, pn_inventory_item_id_in
                                                       );
         WHEN 'CREDIT' THEN
            prc_process_credits(pv_recovery_period_in,
                                pv_gl_period_in,
                                pn_set_of_books_id_in,
                                pn_run_id_out,
                                pv_return_code_out,
                                pv_message_out,
                                pn_trace_flag_in,
                                pn_validate_flag_in,
                                pv_customer_type_in);
         ELSE*/
            prc_process_other(pv_recovery_type_in,
                              pv_recovery_period_in,
                              pv_gl_period_in,
                              pn_set_of_books_id_in,
                              pn_run_id_out,
                              pv_return_code_out,
                              pv_message_out,
                              pn_dflt_coding_flag_in,
                              pn_trace_flag_in,
                              pn_validate_flag_in,
                              pv_customer_type_in,
                              pn_owner_party_id_in,
                              pn_seof_rk_in);
      --END CASE;
   --
   EXCEPTION
      WHEN OTHERS THEN
         om_interface_log.prc_log_error( c_procedure_name, 'Error: ' || SQLERRM);
         om_log_batch_utl.prc_set_error_on;
         om_log_batch_utl.prc_set_error_end_of_package(c_procedure_name,
                                                        pv_return_code_out,
                                                        pv_message_out);
   END prc_process_recoveries;
--
END OM_recover;
/