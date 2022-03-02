-- /*************************************************************************************************
--  Changes:
--  Date		Who						Notes
--  ----------	---						--------------------------------------------------------------
--  01/03/2022	Fender Mora 			step 1 : Preparing the data
--  ****************************************************************************************************/

-- 1. Validate if the creation of  script to move historical data, Just Take records to include 2019 to current: 2/3/2022
CREATE OR ALTER PROC INDF_3911.[test move historical data include 2019 to 2_03_2022]
AS
BEGIN

    -- Temp tables
    IF OBJECT_ID('expected') IS NOT NULL DROP TABLE expected;
    IF OBJECT_ID('actual') IS NOT NULL DROP TABLE actual;

    SELECT mw.[MarketId], mf.[DisbursementId]
    INTO expected
    FROM [EZPMR].[dbo].[MarketWorksheets] mw
             INNER JOIN [EZPMR].[dbo].[Selections] s ON [s].[WorksheetId] = [mw].[WorksheetId]
             INNER JOIN [EZPMR].[dbo].[Entries] e ON [e].[SelectionId] = [s].[SelectionId]
             INNER JOIN [EZPMR].[dbo].[MiscFunds] mf ON [mf].[EntryId] = [e].[EntryId]
    WHERE s.[FundingTypeId] = 9 -- Local
      AND mw.[Year] >= 2019     -- reporting years 2019 and forward
      AND mw.[Filed] = 1 -- pmr was submitted (creating disbursemnt records)

    SELECT * INTO actual FROM dbo.LocalFundsQA

    EXEC TSQLT.AssertEqualsTable expected, actual;
END
GO

-- 2. Validate if the creation of  script to move historical data, Just Take records to include 2019 to current: 2/3/2022
CREATE OR ALTER PROC INDF_3911.[test getting the primary hospital FundraisingEntityId for the market]
AS
BEGIN

    -- Temp tables
    IF OBJECT_ID('expected') IS NOT NULL DROP TABLE expected;
    IF OBJECT_ID('actual') IS NOT NULL DROP TABLE actual;

    -- get the primary hospital for each market
    SELECT fe.[FundraisingEntityId], h.[MarketId]
    INTO expected
    FROM [Core].[dbo].[FundraisingEntities] fe
             INNER JOIN [Core].[dbo].[Hospitals] h ON [h].[FundraisingEntityId] = [fe].[FundraisingEntityId]
    WHERE [fe].[FundraisingCategoryId] = 10
      AND h.[PrimaryHospital] = 1 --Hospital Partners, Primary Hospital

    SELECT * INTO actual FROM dbo.HospitalInfoQA

    EXEC TSQLT.AssertEqualsTable expected, actual;
END
GO


-- 3. Validate UpdateRows Afected
CREATE OR ALTER PROC INDF_3911.[test Update Disbursements with new primary hospital]
AS
BEGIN

    DECLARE @UpdatePrimaryHospital INT =
        (
            SELECT count(*)
            FROM dbo.LocalFundsQA lf
                     INNER JOIN dbo.HospitalInfoQA hi ON [hi].[MarketId] = [lf].[MarketId]
                     INNER JOIN [Core].[dbo].[Disbursements] d ON [d].[DisbursementId] = [lf].[DisbursementId]
        );

    EXEC TSQLT.AssertEquals 0, @UpdatePrimaryHospital
END
GO

-- Getting total testing cases created
DECLARE @TestClassId INT;
SELECT @TestClassId = schemaId
FROM tSQLt.Private_ResolveName('INDF_3911')

SELECT tSQLt.Private_GetQuotedFullName(object_id) as TestCases
FROM sys.procedures
WHERE schema_id = @TestClassId
  AND LOWER(name) LIKE 'test%';
GO


