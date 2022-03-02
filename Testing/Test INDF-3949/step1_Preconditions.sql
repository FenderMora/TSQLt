/*************************************************************************************************
Changes:
Date		Who						Notes
----------	---						--------------------------------------------------------------
17/02/2022	Fender Mora 			step 1 : Preparing the data and creating a class
****************************************************************************************************/

USE QaTesting
BEGIN TRAN INDF_3949_TransactionProcess

-- Declaring variables
Declare @FileName VARCHAR(255) = 'QA.csv',
    @UserContactId INT ='30432',
    @BatchNumber VARCHAR(25) ='3210',
    @RecordTypeId INT,
    @FundraisingYear INT,
    @DirectToHospitalFlag BIT,
    @Foundation BIT,
    @BatchTypeId INT,
    @UploadId VARCHAR(20)


-- Running Sp
EXEC INDF_3949_Transaction @FileName, @UserContactId, @BatchNumber,
     @RecordTypeId, @FundraisingYear, @DirectToHospitalFlag,
     @Foundation, @BatchTypeId, @UploadId

--1 creating a class
EXEC tSQLt.NewTestClass 'INDF_3949';

IF EXISTS(SELECT TOP 1 *
          FROM tSQLt.Private_ResolveName('INDF_3949'))
    SELECT 'NEW TESTS CLASS INDF_3949 CREATED ' as Msg
ELSE
    SELECT 'FAILED ' as Msg
