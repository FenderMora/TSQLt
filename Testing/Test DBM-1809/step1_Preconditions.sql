/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
04/03/2022	Fender Mora 			step 1 : Preparing the data and creating a class
****************************************************************************************************/

USE dnT1Dev

--1 creating a class
EXEC tSQLt.NewTestClass 'DBM_1809';


IF EXISTS (SELECT TOP  1 * FROM tSQLt.Private_ResolveName('DBM_1809'))
    SELECT 'NEW TESTS CLASS DBM_1809 CREATED ' as Msg
ELSE
    SELECT 'FAILED ' as Msg