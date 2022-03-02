/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
14/02/2022	Fender Mora 			step 1 : Preparing the data and creating a class
****************************************************************************************************/

USE dnT1Dev
BEGIN TRAN DBM_1800_TransactionProcess
EXEC  DBM_1800_Transaction

--1 creating a class
EXEC tSQLt.NewTestClass 'DBM_1800';


IF EXISTS (SELECT TOP  1 * FROM tSQLt.Private_ResolveName('DBM_1800'))
    SELECT 'NEW TESTS CLASS DBM_1800 CREATED ' as Msg
ELSE
    SELECT 'FAILED ' as Msg