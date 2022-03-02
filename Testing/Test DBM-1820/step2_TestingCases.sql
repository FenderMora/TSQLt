-- /*************************************************************************************************
--  Changes:
--  Date		Who						Notes
--  ----------	---						--------------------------------------------------------------
--  17/02/2022	Fender Mora 			step 1 : Preparing the data
--  ****************************************************************************************************/
--1. test if table Disbursements expected before change exists
CREATE OR ALTER PROC DBM_1820.[test if table Disbursements expected]
AS
BEGIN

    EXEC tSQLt.AssertObjectExists @ObjectName = N'expected'
END
GO


-- 2. Validation if the data is Updated Successful
CREATE OR ALTER PROC DBM_1820.[test Validation if the data is Updated Successful]
AS
BEGIN
    IF OBJECT_ID('actual') IS NOT NULL DROP TABLE actual;
    IF OBJECT_ID('expected') IS NOT NULL DROP TABLE expected;

    --- inserting of actual table
    SELECT [FundraisingEntityId],
           [CampaignDetailsId],
           Amount
    into actual
    FROM [dbo].[Disbursements]
    WHERE [DisbursementId]
              IN (16989510, 16989511, 16989513)


--- Creation of expected table
    CREATE TABLE expected
    (
        FundraisingEntityId INT,
        CampaignDetailsId   INT,
        Amount              money
    )

--inserting expected data
    INSERT expected (FundraisingEntityId,
                     CampaignDetailsId,
                     Amount)
    VALUES (5479, 179904, 20000.0000),
           (5479, 179904, 35000.0000),
           (5479, 179904, 7500.0000)

    EXEC tSQLt.AssertEqualsTable 'expected', 'actual';

END
GO

-- 3. Total Validation
CREATE OR ALTER PROC DBM_1820.[test Total Validation]
AS
BEGIN
   IF OBJECT_ID('actual') IS NOT NULL DROP TABLE actual;
    IF OBJECT_ID('expected') IS NOT NULL DROP TABLE expected;

    --- Creation of expected table
    SELECT [FundraisingEntityId],
           [CampaignDetailsId],
           Amount
    into actual
    FROM [dbo].[Disbursements]
    WHERE [DisbursementId]
              IN (16989510, 16989511, 16989513)


--- Creation of expected table
    CREATE TABLE expected
    (
        FundraisingEntityId INT,
        CampaignDetailsId   INT,
        Amount              money
    )

--inserting expected data
    INSERT expected (FundraisingEntityId,
                     CampaignDetailsId,
                     Amount)
    VALUES (5479, 179904, 20000.0000),
           (5479, 179904, 35000.0000),
           (5479, 179904, 7500.0000)

    DECLARE @valueExpected MONEY =0;
    DECLARE @valueActual MONEY =0;

    SET @valueExpected = (SELECT SUM(Amount) FROM expected)
       SET @valueActual = (SELECT SUM(Amount) FROM actual)
    EXEC tSQLt.AssertEqualsTable 'expected', 'actual';

END
GO
-- Getting total testing cases created
DECLARE @TestClassId INT;
SELECT @TestClassId = schemaId
FROM tSQLt.Private_ResolveName('DBM_1820')

SELECT tSQLt.Private_GetQuotedFullName(object_id) as TestCases
FROM sys.procedures
WHERE schema_id = @TestClassId
  AND LOWER(name) LIKE 'test%';
GO
