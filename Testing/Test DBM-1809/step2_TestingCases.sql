-- /*************************************************************************************************
--  Changes:
--  Date		Who						Notes
--  ----------	---						--------------------------------------------------------------
--  04/03/2022	Fender Mora 			step 1 : Preparing the data
--  ****************************************************************************************************/

--1. test if Objects exists DRTVMonthlyStewardshipFile
CREATE OR ALTER PROC DBM_1809.[test if Objects exists DRTVMonthlyStewardshipFile]
AS
BEGIN

    --Validation if table exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

    --validation if the Sp Exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

END
GO

--2. test Build DRTVMonthlyStewardshipFile Data
CREATE OR ALTER PROC DBM_1809.[test Build DRTVMonthlyStewardshipFile Data]
AS
BEGIN

    --Validation if table exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

    --validation if the Sp Exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

END
GO
-- 3.test Cleanup DRTVMonthlyStewardshipFile data
CREATE OR ALTER PROC DBM_1809.[test Cleanup DRTVMonthlyStewardshipFile data]
AS
BEGIN

    --Validation if table exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

    --validation if the Sp Exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

END
GO

-- 4.test Insert DRTVMonthlyDonorAppealLoad record
CREATE OR ALTER PROC DBM_1809.[test insert DRTVMonthlyDonorAppealLoad record]
AS
BEGIN

    --Validation if table exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

    --validation if the Sp Exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

END
GO
-- 5.test Run views to pull data and export to .txt/.csv
CREATE OR ALTER PROC DBM_1809.[test Run views to pull data and export to .txt/.csv]
AS
BEGIN

    --Validation if table exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

    --validation if the Sp Exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

END
GO

-- 7. Run adm.uspDonorAppealLoad 1
CREATE OR ALTER PROC DBM_1809.[test Update FilesToLoad Record]
AS
BEGIN

    --Validation if table exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

    --validation if the Sp Exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

END
GO

-- 6.test Update FilesToLoad Record
CREATE OR ALTER PROC DBM_1809.[test Update FilesToLoad Record]
AS
BEGIN

    --Validation if table exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

    --validation if the Sp Exist
    EXEC tSQLt.AssertObjectExists @ObjectName = N'DRTVMonthlyStewardshipFile'

END
GO

-- Getting total testing cases created
DECLARE @TestClassId INT;
SELECT @TestClassId = schemaId
FROM tSQLt.Private_ResolveName('DBM_1809')

SELECT tSQLt.Private_GetQuotedFullName(object_id) as TestCases
FROM sys.procedures
WHERE schema_id = @TestClassId
  AND LOWER(name) LIKE 'test%';
GO
