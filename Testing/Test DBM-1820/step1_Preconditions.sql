/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
17/02/2022	Fender Mora 			step 1 : Preparing the data and creating a class
****************************************************************************************************/

USE core
BEGIN TRAN DBM_1820_TransactionProcess
EXEC  DBM_1820_Transaction

--1 creating a class
EXEC tSQLt.NewTestClass 'DBM_1820';


IF EXISTS (SELECT TOP  1 * FROM tSQLt.Private_ResolveName('DBM_1820'))
    SELECT 'NEW TESTS CLASS DBM_1820 CREATED ' as Msg
ELSE
    SELECT 'FAILED ' as Msg