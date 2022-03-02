/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
28/02/2022	Fender Mora 			step 3 : Execute the Test cases 
****************************************************************************************************/

-- |1 |[INDF_3949].[test Insert into dbo.RTDFileUploaderLog table for error logging]
-- |2 |[INDF_3949].[test validating the File has all the data]

tsqlt.run 'INDF_3949'

-- Test Result table 
SELECT * FROM tsqlt.TestResult

-- Postconditions 
ROLLBACK TRAN INDF_3949_TransactionProcess
