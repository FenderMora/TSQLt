/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
17/02/2022	Fender Mora 			step 3 : Execute the Test cases 
****************************************************************************************************/

-- The following test will be executed: 
--  1. DBM_1820.[test if table Disbursements expected before change exists]
--  2. DBM_1820.[Validation if the data is Updated Successful]
--  3. DBM_1820.[Total Validation]


-- Run test
tsqlt.run 'DBM_1820'

-- Test Result table 
SELECT * FROM tsqlt.TestResult

-- Postconditions 
-- ROLLBACK TRAN DBM_1820_TransactionProcess
