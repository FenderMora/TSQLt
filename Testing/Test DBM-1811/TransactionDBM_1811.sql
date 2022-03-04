-- =======================================================
-- Create Stored Procedure Template for Azure SQL Database
-- =======================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:      Stuart Moffitt
-- Create Date: 3/2/2022
-- Description: Stored Proc to update radiothon recurringTransaction records' CMN Market ID
-- =============================================
CREATE PROCEDURE dbo.uspUpdateRadiothonRecurringTransactionCMNMarketId_QA

AS
BEGIN

BEGIN TRAN

--  ***  Update One Market Radiothons
---------------------------------------------------------------------------------------------------

--SELECT r.recurringTransactionId,m.CMNMarketId,r.campaignid,r.hospitalid,c.campaignName,h.entityName
UPDATE r
	SET r.cmnMarketID = m.cmnMarketID
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

  PRINT CONCAT( @@ROWCOUNT , ' single market radiothon records updated.')

-- ***  Update Syndicated Radiothons
---------------------------------------------------------------------------------------------------

--SELECT r.recurringTransactionId,z.cmnmarketid
UPDATE r
	SET r.cmnMarketID = z.CmnMarketId
FROM dbo.recurringTransaction r
 INNER JOIN dbo.donor d
  ON r.donorid = d.donorID
 INNER JOIN dbo.PostalCodesToMarket z
  ON LEFT(d.postalcode,5) = z.PostalCode
 INNER JOIN dbo.campaign c
  ON r.campaignID = c.campaignID
 INNER JOIN dbo.parentCampaign pc
  ON c.parentCampaignId = pc.parentCampaignId
WHERE r.cmnMarketID IS NULL
  AND c.campaignTypeID = 1
  AND pc.CMNMarketUpdateType = 3

  PRINT CONCAT( @@ROWCOUNT , ' syndicated radiothon records updated.')

--ROLLBACK TRAN
COMMIT TRAN

END
GO