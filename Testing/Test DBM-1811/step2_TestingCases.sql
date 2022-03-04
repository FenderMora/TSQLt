-- /*************************************************************************************************
--  Changes:
--  Date		Who						Notes
--  ----------	---						--------------------------------------------------------------
--  04/03/2022	Fender Mora 			step 1 : Preparing the data
--  ****************************************************************************************************/

--1. test if table Disbursements expected before change exists
CREATE OR ALTER PROC DBM_1811.[test single market radiothon records updated]
AS
BEGIN
    declare @expected int =0;
    declare @Real int =
        (
            select count(*)
            FROM dbo.recurringTransaction r
                     INNER JOIN dbo.campaign c
                                ON r.campaignID = c.campaignID
                     INNER JOIN dbo.parentCampaign pc
                                ON c.parentCampaignId = pc.parentCampaignId
                     INNER JOIN dbo.hospital h
                                ON r.hospitalID = h.hospitalID
                     INNER JOIN dbo.market m
                                ON m.marketID = h.marketID
            WHERE r.cmnMarketID IS NULL
              AND r.deletedYN = 0
              AND c.campaignTypeID = 1
              AND pc.CMNMarketUpdateType = 1
        );

    EXEC tSQLt.AssertEquals @Real, @expected
END
GO

--2. test if update syndicated radiothon records updated.
CREATE OR ALTER PROC DBM_1811.[test  syndicated radiothon records updated.]
AS
BEGIN
    declare @expected int =0;
    declare @Real int =
        (
            select count(*)
            FROM dbo.recurringTransaction r
                     INNER JOIN dbo.donor d
                                ON r.donorid = d.donorID
                     INNER JOIN dbo.PostalCodesToMarket z
                                ON LEFT(d.postalcode, 5) = z.PostalCode
                     INNER JOIN dbo.campaign c
                                ON r.campaignID = c.campaignID
                     INNER JOIN dbo.parentCampaign pc
                                ON c.parentCampaignId = pc.parentCampaignId
            WHERE r.cmnMarketID IS NULL
              AND c.campaignTypeID = 1
              AND pc.CMNMarketUpdateType = 3
        );

    EXEC tSQLt.AssertEquals @Real, @expected
END
GO


-- Getting total testing cases created
DECLARE @TestClassId INT;
SELECT @TestClassId = schemaId
FROM tSQLt.Private_ResolveName('DBM_1811')

SELECT tSQLt.Private_GetQuotedFullName(object_id) as TestCases
FROM sys.procedures
WHERE schema_id = @TestClassId
  AND LOWER(name) LIKE 'test%';
GO

