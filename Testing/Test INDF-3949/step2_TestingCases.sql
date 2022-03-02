-- /*************************************************************************************************
--  Changes:
--  Date		Who						Notes
--  ----------	---						--------------------------------------------------------------
--  17/02/2022	Fender Mora 			step 1 : Preparing the data
--  ****************************************************************************************************/


-- 1. Validate if Sp inserted record into dbo.RTDFileUploaderLog table for error logging
CREATE OR ALTER PROC INDF_3949.[test Insert into dbo.RTDFileUploaderLog table for error logging]
AS
BEGIN

    DECLARE @FileName VARCHAR(255) = 'QA.csv';
    DECLARE @FileNameExpected VARCHAR(255);

    SELECT @FileNameExpected = FileName
    FROM TemporaryData.dbo.RTDFileUploaderLog
    WHERE CreatedDate = CAST(GETDATE() AS DATE)

    EXEC TSQLT.AssertEquals @FileNameExpected, @FileName;
END
GO

--2. validating the File has all the data in the correct format by running spRTDDisbursementErrors
CREATE OR ALTER PROC INDF_3949.[test validating the File has all the data]
AS
BEGIN

    DECLARE @BatchId INT =3210;
    DECLARE @RTDLogId INT =0;
    DECLARE @FileName VARCHAR(255) = 'QA.csv';

    -- Temp tables
    IF OBJECT_ID('hasError') IS NOT NULL DROP TABLE hasError;
    IF OBJECT_ID('hasErrorRTDLog') IS NOT NULL DROP TABLE hasErrorRTDLog;

    -- Populated hasError table
    SELECT Error
    into hasError
    FROM TemporaryData.dbo.RTDFileUploaderLog
    WHERE CreatedDate = CAST(GETDATE() AS DATE)
      AND FileName = @FileName

    -- Populated hasErrorRTDLog table
    SELECT *
    into hasErrorRTDLog
    FROM Core.dbo.RTDLog
    WHERE RTDLogId = @BatchId

    select top 1 @RTDLogId = RTDLogId from hasErrorRTDLog

    IF ((SELECT count(*) FROM hasError) > 0)
        BEGIN
            -- Log Email should have a detail saved into Core.dbo.RTDLog table
            EXEC TSQLT.AssertEquals @RTDLogId, @BatchId;
        END
    ELSE
        BEGIN
            -- If and Error was written into a error field this table should be populated
            EXEC tSQLt.AssertEmptyTable 'hasError';
            EXEC tSQLt.AssertEmptyTable 'hasErrorRTDLog';
        END


END
GO


-- Getting total testing cases created
DECLARE @TestClassId INT;
SELECT @TestClassId = schemaId
FROM tSQLt.Private_ResolveName('INDF_3949')

SELECT tSQLt.Private_GetQuotedFullName(object_id) as TestCases
FROM sys.procedures
WHERE schema_id = @TestClassId
  AND LOWER(name) LIKE 'test%';
GO

