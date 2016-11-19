CREATE OR REPLACE PACKAGE OM.om_utl AS
 -- $Header: V1_01_1__om_utl_PACKAGESPEC.sql  2016/11/10 1.0 jjose $
 --*****************************************************************************
 --*
 --* Application: CAS Install Base Utilities.
 --* Program: om_utl PL/SQL Package
 --*
 --* Title: All common functions/procedures for Install Base
 --*
 --* Purpose: This package contains all utility procedures and functions used
 --*			  by install base.
 --*
 --* Ver Rel  Date			 Description
 --* --------------------------------------------------------------------------
 --* 1.0  0   2007-Mar-29	 Bill Lupton - Created the package.
 --* 2.0  0   2007-Jun-01	 Bill Lupton - added new function: fn_bps_is_valid().
 --* 2.0 r0   June 8 2007	 Bill Lupton - update fn_bps_is_valid with code provided by Julia.
 --* 2.0 r1   June 12 2007  Bill Lupton - added prc_get_default_gl_coding.
 --*												 - update fn_bps_is_valid with code provided by Julia.
 --* 3.0 r0   June 15 2007  Bill Lupton - modify prc_get_default_gl_coding to use different generic table.
 --* 4.0 	  July 19 2007  Bill Lupton - change name of bill_to parameter in select_customer_info.
 --* 4.1 	  Aug 16 2007	 Bill Lupton - undo previous change of parameter name.
 --* 4.2 	  Aug 17 2007	 Bill Lupton - prc_select_customer_info - undo fix.
 --* 4.3 	  Dec 18 2007	 Bill Lupton - alert 164186 - update fn_get_gl_period_name - truncate given date.
 --* 5.0 	  Aug 25 2010	 Ketan Doshi - alert # 191418 created new functions fn_select_extended_attribute and fn_get_asset_param_id
 --*
 --* 1.0    Nov 10 2016  James Jose Refactored the package for the Order Management stream of SMTP Project
 --*****************************************************************************
 --
 --*************************
 --* Type definitions
 --*************************
 --
 --*************************
 --* Function definitions
 --*************************
 --
 FUNCTION fn_select_catalog_element (pn_seof_rk_in IN om_service_offerings.seof_rk%TYPE,
  pv_parameter_name_in IN om_service_parameters.parameter_name%TYPE)
  RETURN VARCHAR2;
 --
 --Alert # 191418 created new function fn_select_extended_attribute
 /*FUNCTION fn_select_extended_attribute (pn_asset_param_id_in IN om_asset_recovery_params.arpa_rk %TYPE, --om_assets.asset_param_id%TYPE,
  pn_attribute_in IN om_arp_values.arpa_rk%TYPE)
  RETURN VARCHAR2;*/
 --
 FUNCTION fn_select_extended_attribute (pn_aset_rk_in IN om_assets.aset_rk%TYPE,
  pv_asset_param_code_in IN om_asset_recovery_params.asset_param_code%TYPE)
   RETURN VARCHAR2;

 -- Alert # 191418 created new function fn_get_asset_param_id
 FUNCTION fn_get_arpa_rk ( --fn_get_asset_param_id (
  pv_asset_param_code_in IN om_asset_recovery_params.asset_param_code%TYPE
 )
  RETURN NUMBER;
 --
 /*FUNCTION fn_select_recovery_method (
  pn_asset_param_id_in IN om_asset_recovery_params.arpa_rk %TYPE --om_assets.asset_param_id%TYPE
 )
  RETURN VARCHAR2;*/
  
 FUNCTION fn_select_recovery_method (
  pn_aset_rk_in IN om_assets.aset_rk%TYPE
 )
  RETURN VARCHAR2;  
 --
/* FUNCTION fn_select_recovery_started (
  pn_asset_param_id_in IN om_asset_recovery_params.arpa_rk %TYPE --om_assets.asset_param_id%TYPE
 )
  RETURN VARCHAR2;*/
  FUNCTION fn_select_recovery_started (
  pn_aset_rk_in IN om_assets.aset_rk%TYPE
 )
  RETURN VARCHAR2; 
 --
 FUNCTION fn_get_gl_period_name (pn_set_of_books_id_in IN om_fin_sets_of_books.set_of_books_id%TYPE,
  pd_date_in IN DATE)
  RETURN VARCHAR2;
 --
 /*
 FUNCTION fn_get_party_id (
  pv_ministry_code_in IN om_generic_table_details.key%TYPE
 )
  RETURN NUMBER;
 --
 */
 /*FUNCTION fn_get_party_for_logon_org
  RETURN NUMBER;
 --
 */
 /*FUNCTION fn_get_account_id (
  pn_asset_param_id_in IN om_assets.asset_param_id%TYPE
 )
  RETURN NUMBER;
 --
 */
 /*
 FUNCTION fn_get_account_number (
  pn_asset_param_id_in IN om_assets.asset_param_id%TYPE
 )
  RETURN VARCHAR2;
 --
 */
 /*
 FUNCTION fn_get_account_name (
  pn_asset_param_id_in IN om_assets.asset_param_id%TYPE
 )
  RETURN VARCHAR2;
 --
 */
 /*
 FUNCTION fn_get_cust_class_code (
  pn_asset_param_id_in IN om_assets.asset_param_id%TYPE
 )
  RETURN VARCHAR2;
 --
 */
 /*FUNCTION fn_get_bill_to_address (pn_cust_account_id_in IN NUMBER,
  pn_org_id_in IN NUMBER)
  RETURN NUMBER;
 --
 */
 FUNCTION fn_isnumeric (pv_string_in IN VARCHAR2)
  RETURN BOOLEAN;
 --
 /*
 FUNCTION fn_bps_is_valid (pv_tca_party_id IN VARCHAR2, pv_bps_id IN VARCHAR2,
  pv_tca_account_name IN VARCHAR2, pv_bps_cost_centre IN VARCHAR2)
  RETURN VARCHAR2;
 --
 */
 --*************************
 --* Procedure definitions
 --*************************
 --
 PROCEDURE prc_select_recovery_coding (pn_seof_rk_in IN om_service_offerings.seof_rk%TYPE,
  pv_client_out OUT VARCHAR2, pv_resp_out OUT VARCHAR2, pv_srvc_out OUT VARCHAR2,
  pv_stob_out OUT VARCHAR2, pv_proj_out OUT VARCHAR2, pv_return_code_out OUT VARCHAR2,
  pv_message_out OUT VARCHAR2);
 --
 PROCEDURE prc_get_gl_period_dates (pv_fpse_rk_in IN om_fin_periods.fpse_rk%TYPE,
  pv_period_name_in IN om_fin_periods.period_name%TYPE,
  pd_start_date_out OUT NOCOPY DATE, pd_end_date_out OUT NOCOPY DATE,
  pn_period_year_out OUT NOCOPY om_fin_periods.period_year%TYPE,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
  
 --
 PROCEDURE prc_select_set_of_books (pn_set_of_books_id_in IN om_fin_sets_of_books.set_of_books_id%TYPE,
  pv_fpse_rk_out OUT NOCOPY om_fin_sets_of_books.fpse_rk%TYPE,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
 --
 PROCEDURE prc_select_party (pn_party_number_in IN om_generic_table_details.data2%TYPE,
  pn_org_id_out OUT NOCOPY om_generic_table_details.key%TYPE,
  pn_party_id_out OUT NOCOPY om_generic_table_details.data1%TYPE,
  pn_account_id_out OUT NOCOPY om_generic_table_details.data3%TYPE,
  pn_account_number_out OUT NOCOPY om_generic_table_details.data4%TYPE,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
 --
 /*PROCEDURE prc_select_customer_info (pn_asset_param_id_in IN om_assets.asset_param_id%TYPE,
  pv_customer_class_code_out OUT NOCOPY hz_cust_accounts.customer_class_code%TYPE,
  pn_account_id_out OUT NOCOPY hz_cust_accounts.cust_account_id%TYPE,
  pv_account_number_out OUT NOCOPY hz_cust_accounts.account_number%TYPE,
  pv_account_name_out OUT NOCOPY hz_cust_accounts.account_name%TYPE,
  pn_party_id_out OUT NOCOPY hz_cust_accounts.party_id%TYPE,
  pn_bill_to_address_out OUT NOCOPY csi_ip_accounts.bill_to_address%TYPE,
  --		 pn_bill_to_site_out 			OUT NOCOPY		 hz_cust_acct_sites_all.cust_acct_site_id%TYPE,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
 --
 */
 /*
 PROCEDURE prc_get_bps_recoveries_stob (pn_asset_param_id_in IN om_assets.asset_param_id%TYPE,
  pv_stob_out OUT NOCOPY gl_code_combinations.segment4%TYPE,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
 --
 */
 PROCEDURE prc_select_recovery_type (pv_recovery_type_in IN om_generic_table_details.key%TYPE,
  pv_recovery_method_out OUT om_generic_table_details.data1%TYPE,
  pv_recovery_frequency_out OUT om_generic_table_details.data2%TYPE,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
 --
 /*
 PROCEDURE prc_get_item_price (pn_seof_rk_in IN om_service_offerings.seof_rk%TYPE,
  pv_customer_class_in IN hz_cust_accounts.customer_class_code%TYPE,
  pv_recovery_period_in IN om_fin_periods.period_name%TYPE,
  pv_fpse_rk_in IN om_fin_periods.fpse_rk%TYPE,
  pn_price_out OUT NOCOPY qp_list_lines.operand%TYPE,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
 --
 */
 /*
 PROCEDURE prc_get_sda_ministry (pn_account_id_in IN hz_cust_accounts.cust_account_id%TYPE,
  pn_party_id_out OUT NOCOPY hz_parties.party_id%TYPE,
  pn_account_id_out OUT NOCOPY hz_cust_accounts.cust_account_id%TYPE,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
 --
 */

 PROCEDURE prc_get_default_gl_coding (--pn_account_id_in IN hz_cust_accounts.cust_account_id%TYPE,
  pv_client_out OUT NOCOPY VARCHAR2, pv_resp_out OUT NOCOPY VARCHAR2,
  pv_service_out OUT NOCOPY VARCHAR2, pv_project_out OUT NOCOPY VARCHAR2,
  pv_return_code_out OUT NOCOPY VARCHAR2, pv_message_out OUT NOCOPY VARCHAR2);
--

END om_utl;
/
