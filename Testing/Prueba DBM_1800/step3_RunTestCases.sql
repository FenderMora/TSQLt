/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
14/02/2022	Fender Mora 			step 3 : Execute the Test cases 
****************************************************************************************************/

-- The following test will be executed: 
--  1. DBM_1800.[test if table exists ParentCampaign]
--  2. DBM_1800.[test adds a column in dbo.ParentCampaign]
--  3. DBM_1800.[test if table exists CMNMarketUpdateType]
--  4. DBM_1800.[test Validation Expected data inserted into a table CMNMarketUpdateType]

-- Run test
tsqlt.run 'DBM_1800'

-- Test Result table 
SELECT * FROM tsqlt.TestResult

-- Postconditions 
ROLLBACK TRAN DBM_1800_TransactionProcess
