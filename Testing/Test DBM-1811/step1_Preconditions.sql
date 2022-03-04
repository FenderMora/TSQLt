/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
17/02/2022	Fender Mora 			step 1 : Preparing the data and creating a class
****************************************************************************************************/

USE dnT1Dev
BEGIN TRAN DBM_1811_TransactionProcess
EXEC  dbo.uspUpdateRadiothonRecurringTransactionCMNMarketId_QA

--1 creating a class
EXEC tSQLt.NewTestClass 'DBM_1811';


IF EXISTS (SELECT TOP  1 * FROM tSQLt.Private_ResolveName('DBM_1811'))
    SELECT 'NEW TESTS CLASS DBM_1811 CREATED ' as Msg
ELSE
    SELECT 'FAILED ' as Msg