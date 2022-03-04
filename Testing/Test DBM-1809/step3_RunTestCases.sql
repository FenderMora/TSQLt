/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
04/03/2022	Fender Mora 			step 3 : Execute the Test cases 
****************************************************************************************************/

-- The following test will be executed: 
-- [DBM_1809].[test Build DRTVMonthlyStewardshipFile Data]
-- [DBM_1809].[test Cleanup DRTVMonthlyStewardshipFile data]
-- [DBM_1809].[test if Objects exists DRTVMonthlyStewardshipFile]
-- [DBM_1809].[test insert DRTVMonthlyDonorAppealLoad record]
-- [DBM_1809].[test Run views to pull data and export to .txt/.csv]
-- [DBM_1809].[test Update FilesToLoad Record]



-- Run test
tsqlt.run 'DBM_1809'

-- Test Result table 
SELECT * FROM tsqlt.TestResult

-- Postconditions 
-- ROLLBACK TRAN DBM_1820_TransactionProcess
