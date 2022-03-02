-- /*************************************************************************************************
--  Changes:
--  Date		Who						Notes
--  ----------	---						--------------------------------------------------------------
--  14/02/2022	Fender Mora 			step 1 : Preparing the data
--  ****************************************************************************************************/
--1. Testing if the parentCampaign Table Exists
CREATE OR ALTER PROC DBM_1800.[test if table exists ParentCampaign]
AS
BEGIN

    EXEC tSQLt.AssertObjectExists @ObjectName = N'parentCampaign'
END
GO

--2. Step 2 test adds a CMNMarketUpdateType column in dbo.ParentCampaign
CREATE OR ALTER PROC DBM_1800.[test adds a column in dbo.ParentCampaign]
AS
BEGIN
    --Validations
    declare @expectedColumnName nvarchar(100) = 'CMNMarketUpdateType';
    declare @newColumnName nvarchar(100) = NULL;

    set @newColumnName = (SELECT top 1 COLUMN_NAME
                          FROM INFORMATION_SCHEMA.COLUMNS
                          WHERE TABLE_NAME = N'parentCampaign'
                            and COLUMN_NAME = 'CMNMarketUpdateType')

    -- Tsqlt
    EXEC tSQLt.AssertEquals @expectedColumnName, @newColumnName

END
GO


--3. Validation if a new table was created
CREATE OR ALTER PROC DBM_1800.[test if table exists CMNMarketUpdateType] AS
BEGIN

    EXEC tSQLt.AssertObjectExists @ObjectName = N'CMNMarketUpdateType'
END

GO


-- 4. Validation Expected data inserted into a table and real table created a step before.
CREATE OR ALTER PROC DBM_1800.[test Validation Expected data inserted into a table CMNMarketUpdateType]
AS
BEGIN
    IF OBJECT_ID('actual') IS NOT NULL DROP TABLE actual;

    IF OBJECT_ID('expected') IS NOT NULL DROP TABLE expected;


--- Creation of expected table
    CREATE TABLE expected
    (
        UpdateType            INT          NOT NULL,
        UpdateTypeDescription VARCHAR(150) NOT NULL,
        ShortDescription      VARCHAR(50)  NOT NULL
    )

--inserting expected data
    INSERT expected (UpdateType,
                     UpdateTypeDescription,
                     ShortDescription)
    VALUES (0,
            'Assigned by another proccess or not assigned.  Includes DRTV and Direct Mail.',
            'Manual Process'),
           (1,
            'Single Market Radiothon, all donors belong to the hospital and market assingned in the campaign set up.',
            'Single Market Radiothon'),
           (2,
            'Multi- Market Radiothon, donors will be assigned markets from instructions after event.',
            'Multi-Market Radiothon'),
           (3,
            'Syndicated Radiothon, donors will be assinged markets by postal code.',
            'Syndicated Radiothon')

-- inserting of data from CMNMarketUpdateType to actual table
    SELECT UpdateType,
           UpdateTypeDescription,
           ShortDescription
    INTO actual
    FROM dbo.CMNMarketUpdateType;

    EXEC tSQLt.AssertEqualsTable 'expected',
         'actual';

END
GO

-- Getting total testing cases created 
DECLARE @TestClassId INT;
SELECT @TestClassId = schemaId
FROM tSQLt.Private_ResolveName('DBM_1800')

SELECT tSQLt.Private_GetQuotedFullName(object_id) as TestCases
FROM sys.procedures
WHERE schema_id = @TestClassId
  AND LOWER(name) LIKE 'test%';
GO