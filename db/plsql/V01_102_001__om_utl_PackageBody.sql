CREATE OR REPLACE PACKAGE BODY OM.om_utl AS
 -- $Header: v1_02_1__om_utl_PackageBody.sql  2016/11/14 1.0 jjose $
 --*****************************************************************************
 --*
 --* Application: OM Install Base Utilities.
 --* Program: om_utl PL/SQL Package
 --*
 --* Title: All common functions/procedures for Install Base
 --*
 --* Purpose: This package contains all utility procedures and functions used
 --*		by install base.
 --*
 --* Release  Date	 Description
 --* --------------------------------------------------------------------------
 --* 1.0 	2007-Mar-29  Bill Lupton - Created the package body.
 --* 2.0 r0   June 1 2007	Bill Lupton - add function fn_bps_is_valid().
 --* 2.0 r0   June 8 2007	Bill Lupton - update fn_bps_is_valid with code provided by Julia.
 --* 2.0 r1   June 12 2007  Bill Lupton - added prc_get_default_gl_coding.
 --*				  - update fn_bps_is_valid with code provided by Julia.
 --* 3.0 r0   June 15 2007  Bill Lupton - modify prc_get_default_gl_coding to use different generic table.
 --* 4.0 r0   June 27 2007  Bill Lupton - fix bug in prc_get_item_price when price effective end date is 1st of month.
 --* 4.0 	July 19 2007  Bill Lupton - fix prc_select_customer_info - return site ID instead of site use ID
 --* 4.0 	Aug 7 2007	Bill Lupton - fix fn_get_bill_to_address - return site ID instead of site use ID
 --* 4.0 	Aug 14 2007  Bill Lupton - change fn_get_bill_to_address back - return site_use_ID as before.
 --* 4.1 	Aug 16 2007  Bill Lupton - rollback changes to prc_select_customer_info (return site_use_id)
 --* 4.2 	Aug 17 2007  Bill Lupton - prc_select_customer_info - undo fix.
 --* 4.3 	Dec 18 2007  Bill Lupton - alert 164186 - update fn_get_gl_period_name - truncate given date.
 --* 5.0 	Aug 26 2010  Ketan Doshi - alert # 191418 created new functions fn_select_extended_attribute and fn_get_arpa_rk
 --*
 --* 1.0  Nov 14 2016  James Jose - Refactored the package for Order Management stream of SMTP project
 --*****************************************************************************
 --
 -- Constants
 --
 gc_version_no   CONSTANT VARCHAR2 (3) := '1.0';
 gc_version_dt   CONSTANT VARCHAR2 (11) := '14-Nov-2016';
 --
 --
 -- Functions
 --
 --***************************************************************************************************
 --* Function : fn_select_catalog_element
 --* Purpose : To fetch catalog element value for given inventory id and parameter_name
 --* Parameters: pn_seof_rk_in -- inventory item ID.
 --*		 pv_parameter_name_in	 -- name of catalog element (e.g. 'Recovery Coding').
 --* Called By : prc_select_recovery_coding, prc_process_recoveries; prc_process_ib_history
 --***************************************************************************************************
 FUNCTION fn_select_catalog_element (pn_seof_rk_in IN om_service_offerings.seof_rk%TYPE,
  pv_parameter_name_in IN om_service_parameters.parameter_name%TYPE)
  RETURN VARCHAR2 IS
  v_parameter_value   om_service_parameters.parameter_value%TYPE;
 BEGIN
  --
  SELECT   ev.parameter_value
	 INTO   v_parameter_value
	 FROM   om_service_parameters ev
	WHERE   ev.seof_rk = pn_seof_rk_in
			  AND ev.parameter_name = pv_parameter_name_in;
  --
  RETURN v_parameter_value;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_select_catalog_element;
 --
 --***************************************************************************************************
 --* Function : fn_select_extended_attribute
 --* Purpose : To fetch extended attribute value for given item instance and attribute code
 --* Parameters: pn_aset_rk_in	-- IB item instance ID.
 --*		 pv_asset_param_code_in -- name of extended attribute (e.g. 'CAS_RECOVERY_START_FLAG').
 --* Called By : fn_select_recovery_started
 --***************************************************************************************************
 FUNCTION fn_select_extended_attribute (pn_aset_rk_in IN om_assets.aset_rk%TYPE,
  pv_asset_param_code_in IN om_asset_recovery_params.asset_param_code%TYPE)
  RETURN VARCHAR2 IS
  --
  v_asset_param_value	 om_arp_values.asset_param_value%TYPE;
 BEGIN
  --
  SELECT   asset_param_value
	 INTO   v_asset_param_value
	 FROM   om_asset_recovery_params ea, om_arp_values eav
	WHERE 		ea.asset_param_code = pv_asset_param_code_in
			--  AND ea.attribute_level = 'GLOBAL'
			  AND eav.arpa_rk = ea.arpa_rk
			  AND eav.aset_rk = pn_aset_rk_in
			  /*AND eav.active_start_date =
					(SELECT	 MAX (active_start_date)
						FROM	 om_arp_values eav2
					  WHERE	 eav2.arpa_rk = eav.arpa_rk
								 AND eav2.aset_rk = eav.aset_rk)*/;
  --
  RETURN v_asset_param_value;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_select_extended_attribute;
 --
 -- Alert # 191418 created new function fn_select_extended_attribute
 --***************************************************************************************************
 --* Function : fn_select_extended_attribute
 --* Purpose : To fetch extended attribute value for given item instance and attribute code
 --* Parameters: pn_aset_rk_in	-- IB item instance ID.
 --*		 pv_asset_param_code_in -- name of extended attribute (e.g. 'CAS_RECOVERY_START_FLAG').
 --* Called By : fn_select_recovery_started
 --***************************************************************************************************

 FUNCTION fn_select_extended_attribute (pn_aset_rk_in IN om_assets.aset_rk%TYPE,
  pn_attribute_in IN om_arp_values.arpa_rk%TYPE)
  RETURN VARCHAR2 IS
  --
  v_asset_param_value	 om_arp_values.asset_param_value%TYPE;
  n_rank 				 NUMBER;
 BEGIN
  --
  SELECT   asset_param_value
	 INTO   v_asset_param_value
	 FROM   /*(SELECT	asset_param_value,
							RANK ()
							 OVER (
							  PARTITION BY asset_param_value
							  ORDER BY active_start_date DESC,
										  asset_param_value_id DESC
							 )
							 rn
				  FROM*/	om.om_arp_values
				 WHERE	arpa_rk = pn_attribute_in
							AND aset_rk = pn_aset_rk_in; /*)
	WHERE   rn = 1;*/
  --
  RETURN v_asset_param_value;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_select_extended_attribute;
 --
 -- Alert # 191418 created new function fn_get_atrribute_id
 --***************************************************************************************************
 --* Function : fn_get_atrribute_id
 --* Purpose : To fetch extended attribute ID for given attribute level and attribute code
 --* Parameters: pv_asset_param_code_in -- name of extended attribute (e.g. 'CAS_RECOVERY_START_FLAG').
 --* Called By : fn_select_recovery_started
 --***************************************************************************************************

 FUNCTION fn_get_arpa_rk (
  pv_asset_param_code_in IN om_asset_recovery_params.asset_param_code%TYPE
 )
  RETURN NUMBER IS
  --
  n_arpa_rk	 om_asset_recovery_params.arpa_rk%TYPE;
 --
 BEGIN
  --

  SELECT   ea.arpa_rk
	 INTO   n_arpa_rk
	 FROM   om.om_asset_recovery_params ea
	WHERE   ea.asset_param_code = pv_asset_param_code_in;
			  --AND ea.attribute_level = 'GLOBAL';
  --
  RETURN n_arpa_rk;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_get_arpa_rk;
 --
 --***************************************************************************************************
 --* Function : fn_select_recovery_method
 --* Purpose : To fetch recovery started status for given inventory item instance
 --* Parameters: pn_aset_rk_in -- IB item instance ID
 --* Called By :
 --***************************************************************************************************
 FUNCTION fn_select_recovery_method (
  pn_aset_rk_in IN om_assets.aset_rk%TYPE
 )
  RETURN VARCHAR2 IS
 BEGIN
  RETURN fn_select_extended_attribute (pn_aset_rk_in,
			'CAS_SYSTEM_RECOVERY_METHOD');
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_select_recovery_method;
 --
 --***************************************************************************************************
 --* Function : fn_select_recovery_started
 --* Purpose : To fetch recovery started status for given inventory item instance
 --* Parameters: pv_instance_id_in -- IB item instance ID
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 FUNCTION fn_select_recovery_started (
  pn_aset_rk_in IN om_assets.aset_rk%TYPE
 )
  RETURN VARCHAR2 IS
 BEGIN
  RETURN fn_select_extended_attribute (pn_aset_rk_in,
			'CAS_RECOVERY_START_FLAG');
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_select_recovery_started;
 --
 --***************************************************************************************************
 --* Function : fn_get_gl_period_name
 --* Purpose : To fetch GL period name for given start/end dates.
 --* Parameters: pd_start_date_in  -- period start date
 --*		 pd_end_date_ind	 -- period end date
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 FUNCTION fn_get_gl_period_name (pn_set_of_books_id_in IN om_fin_sets_of_books.set_of_books_id%TYPE,
  pd_date_in IN DATE)
  RETURN VARCHAR2 IS
  v_period_name	om_fin_periods.period_name%TYPE;
 BEGIN
  --
  SELECT   period_name
	 INTO   v_period_name
	 FROM   om_fin_sets_of_books sob, om_fin_periods pd
	WHERE 		set_of_books_id = pn_set_of_books_id_in
			  AND pd.fpse_rk = sob.fpse_rk
        --pd.period_set_name = sob.period_set_name
			  AND TRUNC (pd_date_in) BETWEEN start_date AND end_date;
  --
  RETURN v_period_name;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN 'fn_get_gl_period_name(): ' || SQLERRM;
 END fn_get_gl_period_name;
 --
 /*
 --***************************************************************************************************
 --* Function : fn_get_party_id
 --* Purpose : To fetch party id for given ministry code.
 --* Parameters: pv_instance_id_in -- IB item instance ID
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 FUNCTION fn_get_party_id (
  pv_ministry_code_in IN cas_generic_table_details.key%TYPE
 )
  RETURN NUMBER IS
  v_party_id	hz_parties.party_id%TYPE;
 BEGIN
  --
  SELECT   prty.party_id
	 INTO   v_party_id
	 FROM   cas_generic_table_details ministry, hz_parties prty
	WHERE 		ministry.category = 'WTS_TCA_MINISTRY_CODE'
			  AND ministry.key = pv_ministry_code_in
			  AND prty.party_number = ministry.data3;
  --
  RETURN v_party_id;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_get_party_id;
 --
 */
 /*
 --***************************************************************************************************
 --* Function : fn_get_party_for_logon_org
 --* Purpose : To fetch party id for org_id of logged on user.
 --* Parameters: none
 --* Called By : IB update form.
 --***************************************************************************************************
 FUNCTION fn_get_party_for_logon_org
  RETURN NUMBER IS
  v_party_num	 om_generic_table_details.data1%TYPE;
 BEGIN
  --
  SELECT   data2 AS party_number
	 INTO   v_party_num
	 FROM   om_generic_table_details
	WHERE   category = 'WTS_ISTORE_ORG_PARTY'
			  AND key = fnd_profile.VALUE ('U_ISTORE_ORG_ID');
  --
  RETURN v_party_num;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_get_party_for_logon_org;
 */
 /*
 --
 --***************************************************************************************************
 --* Function : fn_get_account_id
 --* Purpose : To fetch TCA account id for given item instance. (function wrapper for prc_select_customer_info)
 --* Parameters: pv_instance_id_in -- IB item instance ID
 --* Called By : IB update form
 --***************************************************************************************************
 FUNCTION fn_get_account_id (
  pn_instance_id_in IN csi_item_instances.instance_id%TYPE
 )
  RETURN NUMBER IS
  v_customer_class_code   hz_cust_accounts.customer_class_code%TYPE;
  n_account_id 			  hz_cust_accounts.cust_account_id%TYPE;
  v_account_number		  hz_cust_accounts.account_number%TYPE;
  v_account_name			  hz_cust_accounts.account_name%TYPE;
  n_party_id				  hz_cust_accounts.party_id%TYPE;
  n_bill_to_address		  csi_ip_accounts.bill_to_address%TYPE;
  v_return_code			  VARCHAR2 (1);
  v_message 				  VARCHAR2 (4000);
 --
 BEGIN
  --
  prc_select_customer_info (pn_instance_id_in, v_customer_class_code,
  n_account_id, v_account_number, v_account_name, n_party_id,
  n_bill_to_address, v_return_code, v_message);
  --
  RETURN n_account_id;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END; -- fn_get_account_id
 --
 --***************************************************************************************************
 --* Function : fn_get_account_number
 --* Purpose : To fetch TCA account number for given item instance. (function wrapper for prc_select_customer_info)
 --* Parameters: pv_instance_id_in -- IB item instance ID
 --* Called By : IB update form
 --***************************************************************************************************
 FUNCTION fn_get_account_number (
  pn_instance_id_in IN csi_item_instances.instance_id%TYPE
 )
  RETURN VARCHAR2 IS
  v_customer_class_code   hz_cust_accounts.customer_class_code%TYPE;
  n_account_id 			  hz_cust_accounts.cust_account_id%TYPE;
  v_account_number		  hz_cust_accounts.account_number%TYPE;
  v_account_name			  hz_cust_accounts.account_name%TYPE;
  n_party_id				  hz_cust_accounts.party_id%TYPE;
  n_bill_to_address		  csi_ip_accounts.bill_to_address%TYPE;
  v_return_code			  VARCHAR2 (1);
  v_message 				  VARCHAR2 (4000);
 --
 BEGIN
  --
  prc_select_customer_info (pn_instance_id_in, v_customer_class_code,
  n_account_id, v_account_number, v_account_name, n_party_id,
  n_bill_to_address, v_return_code, v_message);
  --
  RETURN v_account_number;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END; -- fn_get_account_number
 --
 --***************************************************************************************************
 --* Function : fn_get_account_name
 --* Purpose : To . (function wrapper for prc_select_customer_info)
 --* Parameters: pv_instance_id_in -- IB item instance ID
 --* Called By : IB update form
 --***************************************************************************************************
 FUNCTION fn_get_account_name (
  pn_instance_id_in IN csi_item_instances.instance_id%TYPE
 )
  RETURN VARCHAR2 IS
  v_customer_class_code   hz_cust_accounts.customer_class_code%TYPE;
  n_account_id 			  hz_cust_accounts.cust_account_id%TYPE;
  v_account_number		  hz_cust_accounts.account_number%TYPE;
  v_account_name			  hz_cust_accounts.account_name%TYPE;
  n_party_id				  hz_cust_accounts.party_id%TYPE;
  n_bill_to_address		  csi_ip_accounts.bill_to_address%TYPE;
  v_return_code			  VARCHAR2 (1);
  v_message 				  VARCHAR2 (4000);
 --
 BEGIN
  --
  prc_select_customer_info (pn_instance_id_in, v_customer_class_code,
  n_account_id, v_account_number, v_account_name, n_party_id,
  n_bill_to_address, v_return_code, v_message);
  --
  RETURN v_account_name;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_get_account_name;
 --
 --***************************************************************************************************
 --* Function : fn_get_cust_class_code
 --* Purpose : To fetch customer class code for given item instance. (function wrapper for prc_select_customer_info)
 --* Parameters: pv_instance_id_in -- IB item instance ID.
 --* Called By : IB update form
 --***************************************************************************************************
 FUNCTION fn_get_cust_class_code (
  pn_instance_id_in IN csi_item_instances.instance_id%TYPE
 )
  RETURN VARCHAR2 IS
  v_customer_class_code   hz_cust_accounts.customer_class_code%TYPE;
  n_account_id 			  hz_cust_accounts.cust_account_id%TYPE;
  v_account_number		  hz_cust_accounts.account_number%TYPE;
  v_account_name			  hz_cust_accounts.account_name%TYPE;
  n_party_id				  hz_cust_accounts.party_id%TYPE;
  n_bill_to_address		  csi_ip_accounts.bill_to_address%TYPE;
  v_return_code			  VARCHAR2 (1);
  v_message 				  VARCHAR2 (4000);
 --
 BEGIN
  --
  prc_select_customer_info (pn_instance_id_in, v_customer_class_code,
  n_account_id, v_account_number, v_account_name, n_party_id,
  n_bill_to_address, v_return_code, v_message);
  --
  RETURN v_customer_class_code;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_get_cust_class_code;
 */
 --
 --***************************************************************************************************
 --* Function : fn_isnumeric
 --* Purpose : return TRUE if input value can be converted to a number.
 --* Parameters: pv_string_in  -- string to be checked for numeric value.
 --* Called By : prc_process_ib_history.
 --***************************************************************************************************
 FUNCTION fn_isnumeric (pv_string_in IN VARCHAR2)
  RETURN BOOLEAN IS
  n_number	 NUMBER;
 --
 BEGIN
  --
  n_number := pv_string_in;
  RETURN TRUE;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN FALSE;
 END fn_isnumeric;
 --
 /*
 --***************************************************************************************************
 --* Function : fn_get_bill_to_address
 --* Purpose : return site_use_id for bill_to_address for given account id.
 --* Parameters: pn_cust_account_id_in  -- customer account id.
 --*		 pn_org_id_in		-- organization id.
 --* Called By : IB update form
 --***************************************************************************************************
 FUNCTION fn_get_bill_to_address (pn_cust_account_id_in IN NUMBER,
  pn_org_id_in IN NUMBER)
  RETURN NUMBER IS
  n_site_use_id	ar.hz_cust_site_uses_all.site_use_id%TYPE;
 --
 BEGIN
 
  --SELECT suses.site_use_id
  --INTO n_site_use_id
  --FROM hz_cust_acct_sites_all sites,
	--hz_cust_site_uses_all suses
 --WHERE sites.cust_account_id = pn_cust_account_id_in
	--AND sites.status = 'A'
	--AND sites.org_id = pn_org_id_in
	--AND sites.bill_to_flag = 'P'
	--AND suses.cust_acct_site_id = sites.cust_acct_site_id
	--AND suses.site_use_code = 'BILL_TO';

  --
  SELECT   suses.site_use_id
	 INTO   n_site_use_id
	 FROM   hz_cust_acct_sites_all sites, hz_cust_site_uses_all suses
	WHERE 		sites.cust_account_id = pn_cust_account_id_in
			  AND sites.org_id = pn_org_id_in
			  AND sites.status = 'A'
			  AND suses.cust_acct_site_id = sites.cust_acct_site_id
			  AND suses.status = 'A'
			  AND suses.site_use_code = 'BILL_TO'
			  AND suses.primary_flag = 'Y';
  --
  RETURN n_site_use_id;
 --
 EXCEPTION
  WHEN OTHERS THEN
	RETURN NULL;
 END fn_get_bill_to_address;
 --
 */
 /*
 --******************************************************************************
 -- NAME:	fn_bps_is_valid
 -- PURPOSE:  Validates the BPS Cost Centre Id against the TCA Party Id to
 --	  ensure that they have an existing relationship.
 --
 -- REVISIONS:
 -- Ver	  Date	 Author		Description
 -- ---------	----------	---------------  ------------------------------------
 -- 1.0	  2007-05-30  J. Lyuh	 Created .
 --
 -- NOTES:
 --
 --  Object Name:   fn_bps_is_valid
 --  Sysdate:		2007-05-30
 --  Date and Time:	 2007-05-30, 11:04:11 AM, and 2007-05-30 11:04:11 AM
 --  Username:   Julia Lyuh
 --  Table Name:	 hz_relationships
 --
 --******************************************************************************
 --
 FUNCTION fn_bps_is_valid (pv_tca_party_id IN VARCHAR2, pv_bps_id IN VARCHAR2,
  pv_tca_account_name IN VARCHAR2, pv_bps_cost_centre IN VARCHAR2)
  RETURN VARCHAR2 IS
  v_bps_id	 NUMBER;
 BEGIN
  --
  SELECT   reln.object_id
	 INTO   v_bps_id
	 FROM   hz_parties prty, hz_relationships reln, hz_org_contacts cont,
			  hz_cust_acct_sites_all acctsite, hz_cust_site_uses_all sites,
			  hz_cust_accounts ca
	WHERE 		prty.party_name = pv_bps_cost_centre
			  AND prty.party_id = reln.subject_id
			  AND reln.relationship_code = 'CONTACT_OF'
			  AND reln.relationship_id = cont.party_relationship_id
			  AND cont.party_site_id = acctsite.party_site_id
			  AND acctsite.cust_acct_site_id = sites.cust_acct_site_id
			  AND sites.site_use_code = 'BILL_TO'
			  AND ca.cust_account_id = acctsite.cust_account_id
			  AND ca.account_name = pv_tca_account_name
			  AND reln.subject_id = TO_NUMBER (pv_bps_id)
			  AND reln.object_id = TO_NUMBER (pv_tca_party_id);
  --
  RETURN 'Y';
 --
 EXCEPTION
  WHEN NO_DATA_FOUND THEN
	RETURN 'BPS is NOT valid for TCA.';
  WHEN INVALID_NUMBER THEN
	RETURN 'Invalid numeric parameter.';
  WHEN OTHERS THEN
	RETURN 'Error in om_utl.fn_bps_is_valid(): ' || SQLERRM;
 END fn_bps_is_valid;
 --
 */
 ----***************************************************************************************************
 --* Procedure : prc_select_recovery_coding
 --* Purpose : To fetch recovery coding for given inventory item
 --* Parameters: pv_seof_rk_in - inventory item ID
 --*		 pv_client_out 	 - client code
 --*		 pv_resp_out		- responsibility code
 --*		 pv_srvc_out		- service line code
 --*		 pv_stob_out		- STOB code
 --*		 pv_proj_out		- project code
 --*		 pv_return_code_out	  - return code (0=ok, 1=warning, 2=error)
 --*		 pv_message_out	  - optional output message
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 PROCEDURE prc_select_recovery_coding (pn_seof_rk_in IN om_service_offerings.seof_rk%TYPE,
  pv_client_out OUT VARCHAR2, pv_resp_out OUT VARCHAR2, pv_srvc_out OUT VARCHAR2,
  pv_stob_out OUT VARCHAR2, pv_proj_out OUT VARCHAR2, pv_return_code_out OUT VARCHAR2,
  pv_message_out OUT VARCHAR2) IS
  --
  TYPE at_gl_segments IS VARRAY (5) OF VARCHAR2 (10); -- array of length 5 to hold GL code values
  --
  a_gl_segments		 at_gl_segments := at_gl_segments (); -- initialize array
  i						 PLS_INTEGER; -- loop index variable
  v_parameter_value 	 om_service_parameters.parameter_value%TYPE; -- recovery coding
  v_recovery_coding	 om_service_parameters.parameter_value%TYPE; -- string used to parse recovery coding
 --
 BEGIN
  --
  pv_return_code_out := '0'; -- initialize return code
  --
  v_parameter_value :=
	fn_select_catalog_element (pn_seof_rk_in, 'Recovery Coding');
  --
  v_recovery_coding := v_parameter_value; -- copy code string so that original is still available for messages
  -- locate position of first delimiter within recovery coding string
  i := INSTR (v_parameter_value, '.');
  --
  WHILE i > 0 LOOP
	--
	-- append an element to the GL segments array
	--
	a_gl_segments.EXTEND;
	--
	-- extract current value from beginning of string
	--
	a_gl_segments (a_gl_segments.LAST) := SUBSTR (v_recovery_coding, 1, i - 1);
	--
	-- trim the value from the beginning of the recovery coding string
	--
	v_recovery_coding := SUBSTR (v_recovery_coding, i + 1);
	i := INSTR (v_recovery_coding, '.');
  --
  END LOOP;
  --
  -- extract the last value from the recovery coding string
  --
  IF (v_recovery_coding IS NOT NULL) THEN
	a_gl_segments.EXTEND;
	a_gl_segments (a_gl_segments.LAST) := v_recovery_coding;
  END IF;
  --
  IF (a_gl_segments.LAST IS NULL) THEN
	pv_return_code_out := '1';
	pv_message_out :=
	 'Warning: Item recovery coding is missing or blank ' || v_parameter_value;
  ELSIF (a_gl_segments.LAST < 5) THEN
	pv_return_code_out := '1';
	pv_message_out :=
	 'Warning: Incomplete recovery coding: ' || v_parameter_value;
  ELSE
	pv_client_out := a_gl_segments (1);
	pv_resp_out := a_gl_segments (2);
	pv_srvc_out := a_gl_segments (3);
	pv_stob_out := a_gl_segments (4);
	pv_proj_out := a_gl_segments (5);
	--
	-- check GL code segment lengths
	--
	IF (	 LENGTH (pv_client_out) != 3
		 OR LENGTH (pv_resp_out) != 5
		 OR LENGTH (pv_srvc_out) != 5
		 OR LENGTH (pv_stob_out) != 4
		 OR LENGTH (pv_proj_out) != 7) THEN
	 pv_return_code_out := '1';
	 pv_message_out :=
	  'Warning: One or more GL code segments has incorrect length.';
	END IF;
  END IF;
 --
 EXCEPTION
  WHEN OTHERS THEN
	pv_return_code_out := '2';
	pv_message_out := SQLERRM;
 END prc_select_recovery_coding;
 --
 /*
 --***************************************************************************************************
 --* Procedure : prc_get_price
 --* Purpose : Get item price.
 --* Parameters: pn_inventory_item_id_in	- duh.
 --*		 pn_period_year_in	 - fiscal year of GL period.
 --*		 pv_customer_class_in	- (e.g. MINISTRY_RECOVERIES).
 --*		 pv_recovery_period_in	 - recovery period name (e.g. MAY-08).
 --*		 pv_return_code_out	  - procedure return code ('0'=ok, '1'=warning, '2'=error).
 --*		 pv_message_out	  - optional output message.
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 PROCEDURE prc_get_item_price (
  pn_inventory_item_id_in IN				mtl_system_items_b.inventory_item_id%TYPE,
  pv_customer_class_in	 IN				hz_cust_accounts.customer_class_code%TYPE,
  pv_recovery_period_in  IN				gl_periods.period_name%TYPE,
  pv_period_set_name_in  IN				gl_periods.period_set_name%TYPE,
  pn_price_out 				 OUT NOCOPY qp_list_lines.operand%TYPE,
  pv_return_code_out 		 OUT NOCOPY VARCHAR2,
  pv_message_out				 OUT NOCOPY VARCHAR2
 ) IS
  --
  d_period_start_date	gl_periods.start_date%TYPE;
  d_period_end_date		gl_periods.end_date%TYPE;
  n_period_year			gl_periods.period_year%TYPE;
 --
 BEGIN
  --
  -- get period year and start date
  --
  prc_get_gl_period_dates (pv_period_set_name_in, pv_recovery_period_in,
  d_period_start_date, d_period_end_date, n_period_year, pv_return_code_out,
  pv_message_out);
  --
  SELECT   pr_line.operand price
	 INTO   pn_price_out
	 FROM   cas_generic_table_details pr_src, qp_list_headers_tl pr_list,
			  qp_pricing_attributes pr_attr, qp_list_lines pr_line
	WHERE   pr_src.category = 'WTS_IB_PRICE_LIST'
			  AND pr_src.key =
					TO_CHAR (n_period_year) || ' ' || pv_customer_class_in
			  AND pr_list.name = pr_src.data1
			  AND pr_attr.list_header_id = pr_list.list_header_id
			  AND pr_attr.product_attr_value = TO_CHAR (pn_inventory_item_id_in)
			  AND pr_line.list_line_id = pr_attr.list_line_id
			  AND pr_line.start_date_active <= d_period_start_date
			  AND (pr_line.end_date_active >= d_period_start_date
					 OR pr_line.end_date_active IS NULL);
  --
  pv_return_code_out := '0';
 --
 EXCEPTION
  WHEN OTHERS THEN
	pn_price_out := NULL;
	pv_return_code_out := '2';
	pv_message_out :=
		 'Warning: Price not found for item '
	 || pn_inventory_item_id_in
	 || ' customer class='
	 || pv_customer_class_in
	 || ': '
	 || SQLERRM;
 END prc_get_item_price;
 --
 */
 --***************************************************************************************************
 --* Procedure : prc_get_gl_period_dates
 --* Purpose : To fetch fiscal period start and end dates for given GL period
 --* Parameters: pv_period_name_in	 - GL period name (i.e. MMM-YY)
 --*		 pd_start_date_out	- fiscal period start date
 --*		 pd_end_date_out	  - fiscal period end date
 --*		 pn_period_year_out	 - fiscal year
 --*		 pv_return_code_out	 - procedure return code ('0'=ok, '1'=warning, '2'=error)
 --*		 pv_message_out	 - optional output message
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 
 PROCEDURE prc_get_gl_period_dates (
  pv_fpse_rk_in IN om_fin_periods.fpse_rk%TYPE,
  pv_period_name_in IN om_fin_periods.period_name%TYPE,
  pd_start_date_out		  OUT NOCOPY DATE,
  pd_end_date_out 		  OUT NOCOPY DATE,
  pn_period_year_out 	  OUT NOCOPY om_fin_periods.period_year%TYPE,
  pv_return_code_out 	  OUT NOCOPY VARCHAR2,
  pv_message_out			  OUT NOCOPY VARCHAR2
 ) IS
 BEGIN
  --
  SELECT   start_date, end_date, period_year
	 INTO   pd_start_date_out, pd_end_date_out, pn_period_year_out
	 FROM   om_fin_periods glp
	WHERE   glp.fpse_rk = pv_fpse_rk_in --glp.period_set_name = pv_period_set_name_in
			  AND glp.period_name = pv_period_name_in;
 --
 EXCEPTION
  WHEN OTHERS THEN
	pv_return_code_out := '2';
	pd_start_date_out := NULL;
	pd_end_date_out := NULL;
	pv_message_out := SQLERRM;
 END prc_get_gl_period_dates;
 --
 --***************************************************************************************************
 --* Procedure : prc_select_set_of_books
 --* Purpose : To fetch GL set_of_books_id and period_set_name for given short_name
 --* Parameters: pv_set_of_books_id_in  -- set of books id (e.g. BCGOV=16).
 --*		 pv_period_set_name_out -- output period set name (e.g. BCGOV_GL_CALNDR).
 --*		 pv_return_code_out	 - procedure return code ('0'=ok, '1'=warning, '2'=error)
 --*		 pv_message_out	 - optional output message
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 PROCEDURE prc_select_set_of_books (
  pn_set_of_books_id_in IN 			  om_fin_sets_of_books.set_of_books_id%TYPE,
   pv_fpse_rk_out OUT NOCOPY om_fin_sets_of_books.fpse_rk%TYPE,
  pv_return_code_out 		OUT NOCOPY VARCHAR2,
  pv_message_out				OUT NOCOPY VARCHAR2
 ) IS
 BEGIN
  --
  SELECT  sob.fpse_rk  --period_set_name
	 INTO   pv_fpse_rk_out --pv_period_set_name_out
	 FROM   om_fin_sets_of_books sob
	WHERE   set_of_books_id = pn_set_of_books_id_in;
  --
  pv_return_code_out := '0';
 --
 EXCEPTION
  WHEN OTHERS THEN
	pv_fpse_rk_out := NULL;
	pv_return_code_out := '2';
	pv_message_out := SQLERRM;
 END prc_select_set_of_books;
 --
 --***************************************************************************************************
 --* Procedure : prc_select_party.
 --* Purpose : Fetch party data
 --* Parameters: pv_set_of_books_id_in  -- set of books id (e.g. BCGOV=16).
 --*		 pv_period_set_name_out -- output period set name (e.g. BCGOV_GL_CALNDR).
 --*		 pv_return_code_out	 - procedure return code ('0'=ok, '1'=warning, '2'=error)
 --*		 pv_message_out	 - optional output message
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 PROCEDURE prc_select_party (
  pn_party_number_in   IN				 om_generic_table_details.data2%TYPE,
  pn_org_id_out			  OUT NOCOPY om_generic_table_details.key%TYPE,
  pn_party_id_out 		  OUT NOCOPY om_generic_table_details.data1%TYPE,
  pn_account_id_out		  OUT NOCOPY om_generic_table_details.data3%TYPE,
  pn_account_number_out   OUT NOCOPY om_generic_table_details.data4%TYPE,
  pv_return_code_out 	  OUT NOCOPY VARCHAR2,
  pv_message_out			  OUT NOCOPY VARCHAR2
 ) IS
 BEGIN
  --
  SELECT   key, data1, data3, data4
	 INTO   pn_org_id_out, pn_party_id_out, pn_account_id_out,
			  pn_account_number_out
	 FROM   om_generic_table_details
	WHERE   category = 'WTS_ISTORE_ORG_PARTY' AND data2 = pn_party_number_in;
  --
  pv_return_code_out := '0';
 --
 EXCEPTION
  WHEN OTHERS THEN
	pn_org_id_out := NULL;
	pn_party_id_out := NULL;
	pn_account_id_out := NULL;
	pn_account_number_out := NULL;
	pv_return_code_out := '2';
	pv_message_out := SQLERRM;
 END prc_select_party;
 /*
 --
 --***************************************************************************************************
 --* Procedure : prc_select_customer_info
 --* Purpose : To fetch customer info for given instance_id.
 --* Parameters: pn_instance_id_in -- IB instance ID
 --*		 pv_customer_class_code_out -- (e.g. MINISTRY_RECOVERIES).
 --*		 pv_return_code_out	 - procedure return code ('0'=ok, '1'=warning, '2'=error)
 --*		 pv_message_out	 - optional output message
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 PROCEDURE prc_select_customer_info (
  pn_instance_id_in			 IN				csi_item_instances.instance_id%TYPE,
  pv_customer_class_code_out	 OUT NOCOPY hz_cust_accounts.customer_class_code%TYPE,
  pn_account_id_out				 OUT NOCOPY hz_cust_accounts.cust_account_id%TYPE,
  pv_account_number_out 		 OUT NOCOPY hz_cust_accounts.account_number%TYPE,
  pv_account_name_out			 OUT NOCOPY hz_cust_accounts.account_name%TYPE,
  pn_party_id_out 				 OUT NOCOPY hz_cust_accounts.party_id%TYPE,
  pn_bill_to_address_out		 OUT NOCOPY csi_ip_accounts.bill_to_address%TYPE,
  --	 pn_bill_to_site_out 	OUT NOCOPY	 hz_cust_acct_sites_all.cust_acct_site_id%TYPE,
  pv_return_code_out 			 OUT NOCOPY VARCHAR2,
  pv_message_out					 OUT NOCOPY VARCHAR2
 ) IS
 --
 BEGIN
  --
  SELECT   ipa.bill_to_address, ca.customer_class_code, ca.cust_account_id,
			  ca.account_number, ca.account_name, ca.party_id
	 INTO   pn_bill_to_address_out, pv_customer_class_code_out,
			  pn_account_id_out, pv_account_number_out, pv_account_name_out,
			  pn_party_id_out
	 FROM   csi_i_parties pty, csi_ip_accounts ipa, hz_cust_accounts ca
	WHERE 		pty.instance_id = pn_instance_id_in
			  AND pty.relationship_type_code = 'OWNER'
			  AND ipa.instance_party_id = pty.instance_party_id
			  AND ca.cust_account_id = ipa.party_account_id;
  --
  -- If the bill_to_address is null, then just use the customer info already selected.
  -- Otherwise, use the bill_to_address to fetch customer info through the customer site.
  --
  SELECT   ca.customer_class_code, ca.cust_account_id, ca.account_number,
			  ca.account_name, ca.party_id
	 --		csa.cust_acct_site_id
	 INTO   pv_customer_class_code_out, pn_account_id_out,
			  pv_account_number_out, pv_account_name_out, pn_party_id_out
	 --		pn_bill_to_site_out
	 FROM   hz_cust_site_uses_all csu, hz_cust_acct_sites_all csa,
			  hz_cust_accounts ca
	WHERE 		csu.site_use_id = pn_bill_to_address_out
			  AND csa.cust_acct_site_id = csu.cust_acct_site_id
			  AND ca.cust_account_id = csa.cust_account_id;
  --
  IF (pv_customer_class_code_out IS NULL) THEN
	pv_return_code_out := '1';
	pv_message_out := 'Warning: Customer Class Code is null.';
  ELSE
	pv_return_code_out := '0';
  END IF;
 --
 EXCEPTION
  WHEN OTHERS THEN
	pv_customer_class_code_out := NULL;
	pn_account_id_out := NULL;
	pv_account_name_out := NULL;
	pn_party_id_out := NULL;
	pv_return_code_out := '2';
	pv_message_out := SQLERRM;
 END prc_select_customer_info;
 */
 --
 --***************************************************************************************************
 --* Procedure : prc_get_bps_recoveries_stob
 --* Purpose : To fetch recovery STOB for BPS recoveries handled through interministry JV.
 --* Parameters: pn_instance_id_in -- IB instance ID
 --*		 pv_stob_out	-- recovery STOB.
 --*		 pv_return_code_out -- procedure return code ('0'=ok, '1'=warning, '2'=error)
 --*		 pv_message_out  -- optional output message
 --* Called By :
 --***************************************************************************************************
 PROCEDURE prc_get_bps_recoveries_stob (pv_gtde_category_in  om.om_generic_table_details.category%TYPE,
   pv_gtde_key_in   om.om_generic_table_details.key%TYPE,                     
  --pn_instance_id_in IN				 csi_item_instances.aset_rk%TYPE,
  pv_stob_out			  OUT NOCOPY VARCHAR2, --gl_code_combinations.segment4%TYPE,
  pv_return_code_out   OUT NOCOPY VARCHAR2,
  pv_message_out		  OUT NOCOPY VARCHAR2
 ) IS
  --
  /*n_bill_to_address	 csi_ip_accounts.bill_to_address%TYPE;
  n_gl_id_rev			 hz_cust_site_uses_all.gl_id_rev%TYPE;*/
  
 --
 BEGIN
  --
  SELECT gtde.data1
  INTO   pv_stob_out
  FROM   om_generic_table_details gtde
  WHERE   gtde.category = 'GL_CODE_STOB'
  AND   gtde.key = 'STOB';
  /*SELECT   ipa.bill_to_address, csu.gl_id_rev, cc.segment4 stob
	 INTO   n_bill_to_address, n_gl_id_rev, pv_stob_out
	 FROM   csi_i_parties pty, csi_ip_accounts ipa, hz_cust_site_uses_all csu,
			  gl_code_combinations cc
	WHERE 		pty.instance_id = pn_instance_id_in
			  AND pty.relationship_type_code = 'OWNER'
			  AND ipa.instance_party_id = pty.instance_party_id
			  AND csu.site_use_id = ipa.bill_to_address
			  AND cc.code_combination_id(+) = csu.gl_id_rev;
  --
  IF (n_bill_to_address IS NULL) THEN
	pv_return_code_out := '1';
	pv_message_out :=
	 'Warning: Bill-to address is null for specified instance_id.';
  ELSIF (n_gl_id_rev IS NULL) THEN
	pv_return_code_out := '1';
	pv_message_out :=
	 'Warning: Revenue account is null for specified instance_id.';
  ELSE
	pv_return_code_out := '0';
  END IF;*/
 --
 EXCEPTION
  WHEN OTHERS THEN
	pv_stob_out := NULL;
	pv_return_code_out := '2';
	pv_message_out := 'Error: Could not get BPS STOB: ' || SQLERRM;
 END prc_get_bps_recoveries_stob;
 --
 --***************************************************************************************************
 --* Procedure : prc_select_recovery_type
 --* Purpose : Get recovery method and frequency for given recovery type.
 --* Parameters: pv_recovery_type_in	- type of recovery (e.g. COMMON, ONE TIME, MONTHLY).
 --*		 pv_recovery_method_out  - (e.g. COMM, IB).
 --*		 pv_recovery_frequency_out - (e.g. MONTHLY, ONE TIME).
 --*		 pv_return_code_out	 - procedure return code ('0'=ok, '1'=warning, '2'=error).
 --*		 pv_message_out	 - optional output message.
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 PROCEDURE prc_select_recovery_type (
  pv_recovery_type_in		IN 			  om_generic_table_details.key%TYPE,
  pv_recovery_method_out		OUT NOCOPY om_generic_table_details.data1%TYPE,
  pv_recovery_frequency_out	OUT NOCOPY om_generic_table_details.data2%TYPE,
  pv_return_code_out 			OUT NOCOPY VARCHAR2,
  pv_message_out					OUT NOCOPY VARCHAR2
 ) IS
 BEGIN
  --
  SELECT   data1 recovery_method, data2 recovery_frequency
	 INTO   pv_recovery_method_out, pv_recovery_frequency_out
	 FROM   om_generic_table_details
	WHERE   category = 'WTS_IB_RECOVERY_SOURCE' AND key = pv_recovery_type_in;
  --
  pv_return_code_out := '0';
 --
 EXCEPTION
  WHEN OTHERS THEN
	pv_recovery_method_out := NULL;
	pv_recovery_frequency_out := NULL;
	pv_return_code_out := '2';
	pv_message_out := 'prc_select_recovery_type(): ' || SQLERRM;
 END prc_select_recovery_type;
 /*
 --
 --***************************************************************************************************
 --* Procedure : prc_get_sda_ministry
 --* Purpose : Get recovery method and frequency for given recovery type.
 --* Parameters: pn_account_id_in	- TCA account ID.
 --*		 pn_party_id_out	  - SDA party ID.
 --*		 pn_account_id_out	- SDA account ID.
 --*		 pv_return_code_out	 - procedure return code ('0'=ok, '1'=warning, '2'=error).
 --*		 pv_message_out	 - optional output message.
 --* Called By : prc_process_recoveries
 --***************************************************************************************************
 PROCEDURE prc_get_sda_ministry (
  pn_account_id_in  IN				 hz_cust_accounts.cust_account_id%TYPE,
  pn_party_id_out 	  OUT NOCOPY hz_parties.party_id%TYPE,
  pn_account_id_out	  OUT NOCOPY hz_cust_accounts.cust_account_id%TYPE,
  pv_return_code_out   OUT NOCOPY VARCHAR2,
  pv_message_out		  OUT NOCOPY VARCHAR2
 ) IS
 BEGIN
  --
  SELECT   prty.party_id, acct_out.cust_account_id
	 INTO   pn_party_id_out, pn_account_id_out
	 FROM   hz_cust_accounts acct_in, cas_generic_table_details min_code,
			  hz_parties prty, hz_cust_accounts acct_out
	WHERE 		acct_in.cust_account_id = pn_account_id_in
			  AND min_code.category = 'WTS_TCA_MINISTRY_CODE'
			  AND min_code.key = SUBSTR (acct_in.account_name, 5,
										INSTR (acct_in.account_name, '-', 5) - 5)
			  AND prty.party_number = min_code.data1
			  AND acct_out.account_number = min_code.data2;
  --
  IF (pn_party_id_out IS NULL) THEN
	pv_return_code_out := '1';
	pv_message_out := 'Warning: Could not determine SDA party or account.';
  ELSE
	pv_return_code_out := '0';
  END IF;
 --
 EXCEPTION
  WHEN OTHERS THEN
	pn_party_id_out := NULL;
	pn_account_id_out := NULL;
	pv_return_code_out := '2';
	pv_message_out := 'prc_get_sda_ministry(): ' || SQLERRM;
 END prc_get_sda_ministry;
 */

 --
 --***************************************************************************************************
 --* Procedure : prc_get_default_gl_coding
 --* Purpose : Get default GL coding for given client code.
 --* Parameters: pn_account_id_in	- TCA account ID.
 --*		 pv_client_out 	- responsibility code
 --*		 pv_resp_out	  - responsibility code
 --*		 pv_service_out	 - service line
 --*		 pv_project_out	 - project code
 --*		 pv_return_code_out	 - procedure return code ('0'=ok, '1'=warning, '2'=error).
 --*		 pv_message_out	 - optional output message.
 --* Called By : cas_ib_recover.prc_get_expense_coding.
 --***************************************************************************************************
 PROCEDURE prc_get_default_gl_coding (
  --pn_account_id_in  IN				 hz_cust_accounts.cust_account_id%TYPE,
  pv_client_out		  OUT NOCOPY VARCHAR2,
  pv_resp_out			  OUT NOCOPY VARCHAR2,
  pv_service_out		  OUT NOCOPY VARCHAR2,
  pv_project_out		  OUT NOCOPY VARCHAR2,
  pv_return_code_out   OUT NOCOPY VARCHAR2,
  pv_message_out		  OUT NOCOPY VARCHAR2
 ) IS
 BEGIN
  --
  SELECT   data1 client, data2 resp, data3 service, data4 project
	 INTO   pv_client_out, pv_resp_out, pv_service_out, pv_project_out
	 FROM   /*hz_cust_accounts acct_in,*/ om_generic_table_details min_code
	WHERE 		/*acct_in.cust_account_id = pn_account_id_in
			  AND*/ min_code.category = 'WTS_DEFAULT_EXPENSE'
			  /*AND min_code.key = SUBSTR (acct_in.account_name, 5,
										INSTR (acct_in.account_name, '-', 5) - 5)*/;
  --
  pv_return_code_out := '0';
 --
 EXCEPTION
  WHEN NO_DATA_FOUND THEN
	pv_return_code_out := '1';
	pv_message_out :=
		 'No default GL coding found for account '
	 --|| TO_CHAR (pn_account_id_in)
	 || '.';
  WHEN OTHERS THEN
	-- 	 pv_client_out := NULL;
	-- 	 pv_resp_out := NULL;
	-- 	 pv_service_out := NULL;
	-- 	 pv_project_out := NULL;
	pv_return_code_out := '2';
	pv_message_out := 'prc_get_default_gl_coding(): ' || SQLERRM;
 END;
--

END om_utl;
/
