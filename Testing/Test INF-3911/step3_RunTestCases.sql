/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
01/03/2022	Fender Mora 			step 3 : Execute the Test cases
****************************************************************************************************/

--|1 |[INDF_3911].[test getting the primary hospital FundraisingEntityId for the market]| |Success|
--|2 |[INDF_3911].[test move historical data include 2019 to 2_03_2022]                 | |Success|
--|3 |[INDF_3911].[test Update Disbursements with new primary hospital]                 | |Success|

tsqlt.run 'INDF_3911'

-- Test Result table
SELECT * FROM tsqlt.TestResult

-- Postconditions
ROLLBACK TRAN INDF_3911_TransactionProcess

-- Drop tsqlt.class 'INDF_3911'