/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
1/03/2022	Fender Mora 			step 1 : Preparing the data and creating a class
****************************************************************************************************/

USE QaTesting
BEGIN TRAN INDF_3911_TransactionProcess

-- Running Sp
EXEC INDF_3911_Transaction

--1 creating a class
EXEC tSQLt.NewTestClass 'INDF_3911';

IF EXISTS(SELECT TOP 1 *
          FROM tSQLt.Private_ResolveName('INDF_3911'))
    SELECT 'NEW TESTS CLASS INDF_3911 CREATED ' as Msg
ELSE
    SELECT 'FAILED' as Msg
