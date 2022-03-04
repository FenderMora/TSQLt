USE [EZPMR]
GO

/****** Object:  StoredProcedure [dbo].[TransformPmrData]    Script Date: 2/23/2022 12:15:29 PM ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO


-- ==========================================================================================
-- Author:		Scott Lance & Ethan Tipton & Kevin Reid
-- Create date: 09/06/2013
-- Description:	Bulk Inserts transformed PMR Records into the Disbursements table
-- Updates    : 07/07/2014 - Update CMNH instead of CMNDB
--            : 09/19/2014 - Treat Dance Marathons like Radiothons
--            : 10/22/2014 - Fixed Pledge Data transform
--            : 01/13/2015 - Updated FundraisingYear calculation
--            : 03/10/2015 - Updates for Core refactor
--            : 06/29/2015 - Treat Telethons like Radiothons
--            : 03/17/2016 - Updates for program to program giving
--            : 04/04/2016 - Updates for Local Direct Mail
--            : 01/06/2017 - Add CampaignType transform for RE/MAX Associates
--            : 03/21/2017 - Non-partner funds for National Programs associated with program
--            : 04/19/2018 - Change parameters passed to spInsertDisbursement
--                         - Remove call to spInsertDisbursementFundraisingEntities
--            : 10/09/2018 - Remove SubMarket
--            : 12/12/2018 - Updates for campaigns database refactor
--            : 01/14/2020 - Update for Corporate Partner Changes EZMPR-119
--            : 09/15/2021 - INDF-2666 Update to include Play Yellow changes 2021
--			  : 02/23/2022 - INDF-3909 Local funds will go to the primary hospital of the contactId that is creating the worksheet
-- ==========================================================================================
ALTER   PROCEDURE [dbo].[TransformPmrData]
	@MarketWorksheetId INT,
	@ContactId INT
AS
BEGIN
	SET NOCOUNT ON;

	-- ==========================================================================================
	-- = this stored procedure references the following external database(s):
	-- =   [Core]
	-- ==========================================================================================

	-- Declare local variables
	DECLARE @PF_IDENTIFIER VARCHAR(255),
			@MF_IDENTIFIER VARCHAR(255),

			-- Funding Groups
			@NATIONAL_PROGRAMS_GROUP INT,
			@NATIONAL_EVENT_GROUP INT,
			@LOCAL_GROUP INT,
			@CORPORATE_PARTNERSHIPS_GROUP INT,

			-- Funding Types
			@DANCEMARATHON INT,
			@EXTRALIFE INT,
			@MJD INT,
			@PRODUCE INT,
			@ENGLISHRADIOTHON INT,
			@HISPANICRADIOTHON INT,
			@TELETHON INT,
			@TORCH INT,
			@DANCEDASH INT,
			@MIRACLECHALLENGE INT,
			@LOCAL INT,
			@INDIVIDUALGIFTS INT,
			@CORPORATEPARTNERSHIPS INT,

			@PROGRAM_FUNDRAISING_CATEGORY INT,
			@RECORDTYPEID INT, 
			@FUNDTYPEID INT,
			@CMN_FUNDRAISING_ENTITY_ID INT,
			@HOSPITAL_FUNDRAISING_ENTITY_ID INT,

			-- Program Fundraising Entity Ids
			@FUNDRAISING_ENTITY_DANCE_DASH INT,
			@FUNDRAISING_ENTITY_UNKNOWN_SCHOOL INT,
			@FUNDRAISING_ENTITY_UNKNOWN_ENGLISH_RADIO_STATION INT,
			@FUNDRAISING_ENTITY_UNKNOWN_HISPANIC_RADIO_STATION INT,
			@FUNDRAISING_ENTITY_MIRACLE_CHALLENGE INT,
			@FUNDRAISING_ENTITY_PRODUCE_FOR_KIDS INT,
			@FUNDRAISING_ENTITY_UNKNOWN_TV_STATION INT,
			@FUNDRAISING_ENTITY_EXTRA_LIFE INT,
			@FUNDRAISING_ENTITY_MIRACLE_JEANS_DAY INT,
			@FUNDRAISING_ENTITY_TORCH_RELAY INT,

			--Programs
			@PROGRAMID_PLAY_YELLOW INT,

			@PLEDGE_TYPE_HOSPITALTELETHONANNOUNCEDTOTAL INT,
			@PLEDGE_TYPE_HOSPITALRADIOTHONANNOUNCEDTOTAL INT,

			@LOCAL_DIRECT_MAIL_CAMPAIGN_ID INT,
			@COUNTRY_ID INT,

			-- Campaign Types
			@CAMPAIGN_TYPE_ID_LOCAL INT

	DECLARE @TempDisbursements TABLE (
		[RecordTypeId] int NOT NULL,
		[FundraisingEntityId] int NULL,
		[FundraisingCategoryId] int NULL,
		[MarketId] int NOT NULL,
		[DirectToHospital] bit NOT NULL,
		[FundraisingYear] int NOT NULL,
		[Amount] money NOT NULL,
		[CurrencyTypeId] int NOT NULL,
		[CampaignDetailsId] int NULL,
		[LocationId] int NULL,
		[DateReceived] date NULL,
		[DateRecorded] date NULL,
		[DonationDate] date NULL,
		[FundTypeId] int NULL,
		[FundingGroupId] int NULL,
		[BatchId] int NULL,
		[CampaignPeriod] int NULL,
		[UploadId] varchar(20) NULL,
		[Comment] varchar(255) NULL,
		[OverlapFundraisingEntityId] int NULL,
		[ProgramId] INT NULL,

		[EventID] nvarchar(255) NULL,
		[EventName] nvarchar(255) NULL,
		[FundingTypeId] int NOT NULL,
		[CampaignType] varchar(25) NULL,
		[EntryId] int NULL,
		[Quarter] int NULL,
		[FundTypeGUID] uniqueidentifier NOT NULL,
		[Inserted] bit NOT NULL,

		[PrimaryKey] int NOT NULL,
		[Id] int IDENTITY(1,1) NOT NULL)
	DECLARE @TempPledgeData TABLE (
		[Id] int IDENTITY(1,1) NOT NULL,
		[FundraisingEntityId] int NULL,
		[MarketId] int NULL,
		[FundraisingYear] int NOT NULL,
		[CampaignDetailsId] int NOT NULL,
		[CurrencyTypeId] int NOT NULL,
		[Amount] money NOT NULL,
		[PledgeTypeId] int NOT NULL,
		[Quarter] smallint NULL,
		[PledgeDate] date NULL,
		[AdjustingAmount] money NULL)
	DECLARE @TempEntrySchools TABLE (
		[EntryId] int NOT NULL,
		[FundraisingEntityId] int NULL)
	DECLARE @TempEntryRadioStations TABLE (
		[EntryId] int NOT NULL,
		[FundraisingEntityId] int NULL)
	DECLARE @TempEntryTvStations TABLE (
		[EntryId] int NOT NULL,
		[FundraisingEntityId] int NULL)
	DECLARE @NewCampaignDetails TABLE (
		[Id] INT IDENTITY(1,1) NOT NULL,
		[CampaignId] INT NULL,
		[Name] VARCHAR(300) NOT NULL,
		[CampaignYear] INT NOT NULL,
		[StartDate] DATETIME NOT NULL,
		[CampaignTypeId] INT NOT NULL,
		[ProgramId] INT NULL)
	DECLARE @NewIds TABLE ([Id] INT NOT NULL)
	DECLARE @LocalDirectMail TABLE ([Id] INT NOT NULL)
	DECLARE @Campaigns TABLE (
		[CampaignId] INT NOT NULL, 
		[CampaignName] VARCHAR(300) NOT NULL, 
		[CampaignTypeId] INT NOT NULL,
		[ProgramId] INT NULL)

	BEGIN TRY
		BEGIN TRANSACTION

		SET @PF_IDENTIFIER = CONVERT(VARCHAR(255), NEWID());
		SET @MF_IDENTIFIER = CONVERT(VARCHAR(255), NEWID());

		SET @NATIONAL_PROGRAMS_GROUP = 1;
		SET @NATIONAL_EVENT_GROUP = 2;
		SET @LOCAL_GROUP = 3;
		SET @CORPORATE_PARTNERSHIPS_GROUP = 4;

		SET @DANCEMARATHON = 1;
		SET @EXTRALIFE = 2;
		SET @MJD = 3;
		SET @PRODUCE = 4;
		SET @ENGLISHRADIOTHON = 5;
		SET @HISPANICRADIOTHON = 6;
		SET @TELETHON = 7;
		SET @TORCH = 8;
		SET @DANCEDASH = 12;
		SET @MIRACLECHALLENGE = 13;
		SET @LOCAL = 9;
		SET @INDIVIDUALGIFTS = 10;
		SET @CORPORATEPARTNERSHIPS = 11;

		SET @PLEDGE_TYPE_HOSPITALTELETHONANNOUNCEDTOTAL = 1;
		SET @PLEDGE_TYPE_HOSPITALRADIOTHONANNOUNCEDTOTAL = 2;

		SET @CAMPAIGN_TYPE_ID_LOCAL = 18;

		-- Get values used for each record
		SELECT @RECORDTYPEID=[RecordTypeId] FROM [Core].[dbo].[vwRecordTypes] WHERE [RecordType] = 'D'; -- RecordType is always D
		SELECT @FUNDTYPEID=[FundTypeId] FROM [Core].[dbo].[vwFundTypes] WHERE [FundType] = 'Cash'; -- FundsCategory is always CASH
		SELECT @CMN_FUNDRAISING_ENTITY_ID=[FundraisingEntityId] FROM [Core].[dbo].[vwFundraisingEntityDetails] WHERE [FriendlyName] = 'ChildrensMiracleNetwork'; -- Should be 20
		SELECT @HOSPITAL_FUNDRAISING_ENTITY_ID= [h].[FundraisingEntityId] FROM  core.dbo.[vwHospitalDetails] h INNER JOIN [dbo].[MarketWorksheets] m ON [h].[MarketId] = m.[MarketId] WHERE [h].[PrimaryHospital] = 1 AND m.[WorksheetId] = @MarketWorksheetId
		SELECT @PROGRAM_FUNDRAISING_CATEGORY=[FundraisingCategoryId] FROM [Core].[dbo].[vwFundraisingCategories] WHERE [FundraisingCategory] = 'Program' -- Should be 2
		SELECT DISTINCT @LOCAL_DIRECT_MAIL_CAMPAIGN_ID = [Campaignid] FROM [Core].[dbo].[vwCampaignCompiledDetails] WHERE [CampaignTypeId] = @CAMPAIGN_TYPE_ID_LOCAL AND [CampaignName] = 'Direct Mail Local' -- Should be 34490
		SELECT @COUNTRY_ID = md.[CountryId] FROM [dbo].[MarketWorksheets] mw INNER JOIN [Core].[dbo].[vwMarketDetails] md ON mw.[MarketId] = md.[MarketId] WHERE mw.[WorksheetId] = @MarketWorksheetId;
		SELECT @PROGRAMID_PLAY_YELLOW=[ProgramId] FROM [Core].[dbo].[vwPrograms] WHERE [ProgramName] = 'Play Yellow';

		-- Get country-specific FundraisingEntityId values
		SET @FUNDRAISING_ENTITY_TORCH_RELAY = 138; 

		IF (@COUNTRY_ID = 1) BEGIN -- US
			SET @FUNDRAISING_ENTITY_DANCE_DASH = 314;
			SET @FUNDRAISING_ENTITY_UNKNOWN_SCHOOL = 130;
			SET @FUNDRAISING_ENTITY_UNKNOWN_ENGLISH_RADIO_STATION = 131;
			SET @FUNDRAISING_ENTITY_UNKNOWN_HISPANIC_RADIO_STATION = 132;
			SET @FUNDRAISING_ENTITY_MIRACLE_CHALLENGE = 312;
			SET @FUNDRAISING_ENTITY_PRODUCE_FOR_KIDS = 135;
			SET @FUNDRAISING_ENTITY_UNKNOWN_TV_STATION = 133;
			SET @FUNDRAISING_ENTITY_EXTRA_LIFE = 137;
			SET @FUNDRAISING_ENTITY_MIRACLE_JEANS_DAY = 136;
		END ELSE IF (@COUNTRY_ID = 2) BEGIN -- Canada
			SET @FUNDRAISING_ENTITY_DANCE_DASH = 313;
			SET @FUNDRAISING_ENTITY_UNKNOWN_SCHOOL = 146;
			SET @FUNDRAISING_ENTITY_UNKNOWN_ENGLISH_RADIO_STATION = 147;
			SET @FUNDRAISING_ENTITY_UNKNOWN_HISPANIC_RADIO_STATION = 148;
			SET @FUNDRAISING_ENTITY_MIRACLE_CHALLENGE = 306;
			SET @FUNDRAISING_ENTITY_PRODUCE_FOR_KIDS = 151;
			SET @FUNDRAISING_ENTITY_UNKNOWN_TV_STATION = 149;
			SET @FUNDRAISING_ENTITY_EXTRA_LIFE = 157;
			SET @FUNDRAISING_ENTITY_MIRACLE_JEANS_DAY = 156;
		END

		-- Get Ids for Schools/Radio Stations/TV Stations
		INSERT INTO @TempEntrySchools ([EntryId], [FundraisingEntityId])
			SELECT ee.[EntryId], dm.[FundraisingEntityId]
			FROM [dbo].[ExtendedEntries] ee 
				INNER JOIN [Core].[dbo].[vwDanceMarathons] dm ON CAST(ee.[Value] AS int) = dm.[DanceMarathonId]
			WHERE ee.[Type] = 'DanceMarathon_KeyID';

		INSERT INTO @TempEntryRadioStations ([EntryId], [FundraisingEntityId])
			SELECT ee.[EntryId], rs.[FundraisingEntityId]
			FROM [dbo].[ExtendedEntries] ee 
				INNER JOIN [Core].[dbo].[vwRadiothonRadioStations] rs ON CAST(ee.[Value] AS int) = rs.[RadiothonId]
			WHERE ee.[Type] = 'Radiothon_KeyID' AND rs.[PrimaryRadioStation] = 1;

		INSERT INTO @TempEntryTvStations ([EntryId], [FundraisingEntityId])
			SELECT ee.[EntryId], ts.[FundraisingEntityId]
			FROM [dbo].[ExtendedEntries] ee 
				INNER JOIN [Core].[dbo].[vwTelethonTvStations] ts ON CAST(ee.[Value] AS int) = ts.[TelethonId]
			WHERE ee.[Type] = 'Telethon_KeyID' AND ts.[PrimaryStation] = 1;

		-- Add PartnerFunds to the temporary disbursements table
		INSERT INTO @TempDisbursements ([RecordTypeId], [FundraisingEntityId], [FundraisingCategoryId], [MarketId], [DirectToHospital],
			[FundraisingYear], [Amount], [CurrencyTypeId], [CampaignDetailsId], [LocationId], [DateReceived], [DateRecorded], [DonationDate],
			[FundTypeId], [FundingGroupId], [BatchId], [CampaignPeriod], [UploadId], [Comment], [OverlapFundraisingEntityId],
			[EventID], [EventName], [FundingTypeId], [CampaignType], [EntryId], [Quarter], [FundTypeGUID], [Inserted], 
			[PrimaryKey])

			SELECT
				@RECORDTYPEID AS [RecordTypeId],
				pp.[FundraisingEntityId] AS [FundraisingEntityId],
				pp.[FundraisingCategoryId] AS [FundraisingCategoryId],
				m.[MarketId] AS [MarketId],
				1 AS [DirectToHospital],
				mw.[Year] AS [FundraisingYear],
				pf.[Amount] AS [Amount],
				c.[CurrencyTypeId] AS [CurrencyTypeId],
				null AS [CampaignDetailsId],
				CASE									-- See if the LocationID is in our PartnerLocations table, if it isn't put in the LocationId
					WHEN (EXISTS(SELECT * FROM [dbo].[PartnerLocations] WHERE [FundraisingEntityId] = pe.[FundraisingEntityId] AND [LocationId] = pf.[LocationId] AND [MarketId] = mw.[MarketId]))
					THEN NULL
					ELSE (SELECT TOP(1) [LocationId] FROM [Core].[dbo].[vwLocationDetails] WHERE [LocationNumber] + '-' + CAST([LocationId] as varchar(20)) = pf.[LocationId] ORDER BY [LocationId])
				END AS [LocationId],
				CONVERT(DATETIME, (						-- Calculate the DateReceived as the last day of the reporting quarter
					CASE mw.[Quarter] 
						WHEN 1 
						THEN '3/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 2 
						THEN '6/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 3 
						THEN '9/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						ELSE '12/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE()) - 1) 
					END)) AS [DateReceived],
				GETDATE() AS [DateRecorded],
				CONVERT(DATETIME, (						-- Calculate the DonationDate as the last day of the reporting quarter
					CASE mw.[Quarter] 
						WHEN 1 
						THEN '3/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 2 
						THEN '6/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 3 
						THEN '9/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						ELSE '12/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE()) - 1) 
					END)) AS [DonationDate],
				@FUNDTYPEID AS [FundTypeId],
				ft.[FundingGroupId] AS [FundingGroupId],
				null AS [BatchId],
				null AS [CampaignPeriod],
				null AS [UploadId],
				pf.[Comment] AS [Comment],
				CASE
					WHEN ft.[FundingTypeId] = @DANCEMARATHON 
					THEN (SELECT TOP(1) [FundraisingEntityId] FROM @TempEntrySchools WHERE [EntryId] = e.[EntryId] ORDER BY [FundraisingEntityId])
					WHEN ft.[FundingTypeId] IN (@ENGLISHRADIOTHON, @HISPANICRADIOTHON)
					THEN (SELECT TOP(1) [FundraisingEntityId] FROM @TempEntryRadioStations WHERE [EntryId] = e.[EntryId] ORDER BY [FundraisingEntityId])
					WHEN ft.[FundingTypeId] = @TELETHON 
					THEN (SELECT TOP(1) [FundraisingEntityId] FROM @TempEntryTvStations WHERE [EntryId] = e.[EntryId] ORDER BY [FundraisingEntityId])
					ELSE NULL
				END AS [OverlapFundraisingEntityId],
				CASE
					WHEN ft.[FundingTypeId] < @LOCAL
					THEN (SELECT TOP(1) [EventId] FROM [dbo].[FundingTypeEvents] WHERE [FundingTypeId] = ft.[FundingTypeId] ORDER BY [EventId])
					ELSE UPPER(cat.[Category])
				END AS [EventID],
				CASE									-- If the Event is a NP or Local/Misc then use the Event Name
					WHEN (s.[FundingTypeId] IN (@ENGLISHRADIOTHON, @HISPANICRADIOTHON, @TELETHON, @DANCEMARATHON, @LOCAL, @INDIVIDUALGIFTS, @CORPORATEPARTNERSHIPS)) 
					THEN e.[EventName]
					ELSE 'GENERAL FUNDRAISING'
				END AS [EventName],
				ft.[FundingTypeId] AS [FundingTypeId],
				CASE
					WHEN ft.[FundingGroupId] in (@NATIONAL_PROGRAMS_GROUP,@NATIONAL_EVENT_GROUP) AND ft.[FundingType] like '%Radiothon'
					THEN 'Radiothon'
					WHEN ft.[FundingGroupId] in (@NATIONAL_PROGRAMS_GROUP,@NATIONAL_EVENT_GROUP) 
					THEN ft.[FundingType]
					ELSE cat.[Category]
				END AS [CampaignType],
				e.[EntryId] AS [EntryId],
				mw.[Quarter] AS [Quarter],
				@PF_IDENTIFIER AS [FundTypeGUID],
				0 AS [Inserted],
				pf.[PartnerFundId] AS [PrimaryKey]
			FROM [dbo].[MarketWorksheets] mw
				INNER JOIN [dbo].[Selections] s ON mw.[WorksheetId] = s.[WorksheetId]
				INNER JOIN [dbo].[FundingTypes] ft ON s.[FundingTypeId] = ft.[FundingTypeId]
				INNER JOIN [dbo].[Entries] e ON s.[SelectionId] = e.[SelectionId]
				INNER JOIN [dbo].[PartnerEntries] pe ON e.[EntryId] = pe.[EntryId]
				INNER JOIN [dbo].[PartnerFunds] pf ON pe.[PartnerEntryId] = pf.[PartnerEntryId]
				INNER JOIN [Core].[dbo].[vwMarkets] m on mw.[MarketId]=m.[MarketId]
				INNER JOIN [Core].[dbo].[vwCountries] c on m.[CountryId]=c.[CountryId]
				INNER JOIN [Core].[dbo].[vwFundraisingEntityDetails] pp ON pe.[FundraisingEntityId]=pp.[FundraisingEntityId]
				RIGHT OUTER JOIN [dbo].[Categories] cat ON cat.[CategoryId] = pf.[CategoryId]
			WHERE mw.[WorksheetId] = @MarketWorksheetId
				AND m.[Active] = 1
				AND pp.[Active] = 1;

		-- Add MiscFunds to the temporary disbursements table
		INSERT INTO @TempDisbursements ([RecordTypeId], [FundraisingEntityId], [FundraisingCategoryId], [MarketId], [DirectToHospital],
			[FundraisingYear], [Amount], [CurrencyTypeId], [CampaignDetailsId], [LocationId], [DateReceived], [DateRecorded], [DonationDate],
			[FundTypeId], [FundingGroupId], [BatchId], [CampaignPeriod], [UploadId], [Comment], [OverlapFundraisingEntityId],
			[EventID], [EventName], [FundingTypeId], [CampaignType], [EntryId], [Quarter], [FundTypeGUID], [Inserted], 
			[PrimaryKey])

			SELECT 
				@RECORDTYPEID AS [RecordTypeId],
				CASE
					WHEN ft.[FundingTypeId] = @DANCEMARATHON 
					THEN (SELECT TOP(1) [FundraisingEntityId] FROM @TempEntrySchools WHERE [EntryId] = e.[EntryId] ORDER BY [FundraisingEntityId])
					WHEN ft.[FundingTypeId] IN (@ENGLISHRADIOTHON, @HISPANICRADIOTHON)
					THEN (SELECT TOP(1) [FundraisingEntityId] FROM @TempEntryRadioStations WHERE [EntryId] = e.[EntryId] ORDER BY [FundraisingEntityId])
					WHEN ft.[FundingTypeId] = @TELETHON 
					THEN (SELECT TOP(1) [FundraisingEntityId] FROM @TempEntryTvStations WHERE [EntryId] = e.[EntryId] ORDER BY [FundraisingEntityId])
					ELSE NULL
				END AS [FundraisingEntityId],
				@PROGRAM_FUNDRAISING_CATEGORY AS [FundraisingCategoryId],
				m.[MarketId] AS [MarketId],
				1 AS [DirectToHospital],
				mw.[Year] AS [FundraisingYear],
				mf.[Amount] AS [Amount],				-- SummaryAmount
				c.[CurrencyTypeId] AS [CurrencyTypeId],
				null AS [CampaignDetailsId],
				null AS [LocationId],					-- Misc Funds don't have a location
				CONVERT(DATETIME, (						-- Calculate the DateReceived as the last day of the reporting quarter
					CASE mw.[Quarter] 
						WHEN 1 
						THEN '3/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 2 
						THEN '6/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 3 
						THEN '9/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						ELSE '12/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE()) - 1) 
					END)) AS [DateReceived],
				GETDATE() AS [DateRecorded],
				CONVERT(DATETIME, (						-- Calculate the DonationDate as the last day of the reporting quarter
					CASE mw.[Quarter] 
						WHEN 1 
						THEN '3/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 2 
						THEN '6/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 3 
						THEN '9/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						ELSE '12/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE()) - 1) 
					END)) AS [DonationDate],
				@FUNDTYPEID AS [FundTypeId],
				ft.[FundingGroupId] AS [FundingGroupId],
				null AS [BatchId],
				null AS [CampaignPeriod],
				null AS [UploadId],
				mf.[Comment] AS [Comment],
				null AS [OverlapFundraisingEntityId],
				CASE
					WHEN ft.[FundingTypeId] < @LOCAL
					THEN (SELECT TOP(1) [EventId] FROM [dbo].[FundingTypeEvents] WHERE [FundingTypeId] = ft.[FundingTypeId] ORDER BY [EventId])
					ELSE UPPER(cat.[Category])
				END AS [EventID],
				CASE									-- If the Event is a NP or Local/Misc then use the Event Name
					WHEN (s.[FundingTypeId] IN (@ENGLISHRADIOTHON, @HISPANICRADIOTHON, @TELETHON, @DANCEMARATHON, @LOCAL, @INDIVIDUALGIFTS, @CORPORATEPARTNERSHIPS)) 
					THEN e.[EventName]
					ELSE 'GENERAL FUNDRAISING' 
				END AS [EventName],
				ft.[FundingTypeId] AS [FundingTypeId],
				CASE
					WHEN ft.[FundingGroupId] in (@NATIONAL_PROGRAMS_GROUP,@NATIONAL_EVENT_GROUP) AND ft.[FundingType] like '%Radiothon'
					THEN 'Radiothon'
					WHEN ft.[FundingGroupId] in (@NATIONAL_PROGRAMS_GROUP,@NATIONAL_EVENT_GROUP) 
					THEN ft.[FundingType]
					ELSE cat.[Category]
				END AS [CampaignType],
				e.[EntryId] AS [EntryId],
				mw.[Quarter] AS [Quarter],
				@MF_IDENTIFIER AS [FundTypeGUID],
				0 AS [Inserted],

				mf.[MiscFundId] as [PrimaryKey]
			FROM [dbo].[MarketWorksheets] mw
				INNER JOIN [dbo].[Selections] s ON mw.[WorksheetId] = s.[WorksheetId]
				INNER JOIN [dbo].[FundingTypes] ft ON s.[FundingTypeId] = ft.[FundingTypeId]		
				INNER JOIN [dbo].[Entries] e ON s.[SelectionId] = e.[SelectionId]
				INNER JOIN [dbo].[MiscFunds] mf ON e.[EntryId] = mf.[EntryId]
				INNER JOIN [Core].[dbo].[vwMarkets] m ON mw.[MarketId]=m.[MarketId]
				INNER JOIN [Core].[dbo].[vwCountries] c ON m.[CountryId]=c.[CountryId]
				RIGHT OUTER JOIN [dbo].[Categories] cat ON cat.[CategoryId] = mf.[CategoryId]
			WHERE mw.[WorksheetId] = @MarketWorksheetId
				AND m.[Active] = 1;

		-- Update the FundraisingEntityId for records that don't have them
		UPDATE @TempDisbursements SET [FundraisingEntityId] = @HOSPITAL_FUNDRAISING_ENTITY_ID WHERE [FundraisingEntityId] IS NULL AND [FundingGroupId] = @LOCAL_GROUP;
		UPDATE @TempDisbursements SET 
			[FundraisingEntityId] = 
				CASE
					WHEN [FundingTypeId] = @DANCEMARATHON THEN @FUNDRAISING_ENTITY_UNKNOWN_SCHOOL
					WHEN [FundingTypeId] = @EXTRALIFE THEN @FUNDRAISING_ENTITY_EXTRA_LIFE
					WHEN [FundingTypeId] = @MJD THEN @FUNDRAISING_ENTITY_MIRACLE_JEANS_DAY
					WHEN [FundingTypeId] = @PRODUCE THEN @FUNDRAISING_ENTITY_PRODUCE_FOR_KIDS
					WHEN [FundingTypeId] = @ENGLISHRADIOTHON THEN @FUNDRAISING_ENTITY_UNKNOWN_ENGLISH_RADIO_STATION
					WHEN [FundingTypeId] = @HISPANICRADIOTHON THEN @FUNDRAISING_ENTITY_UNKNOWN_HISPANIC_RADIO_STATION
					WHEN [FundingTypeId] = @TELETHON THEN @FUNDRAISING_ENTITY_UNKNOWN_TV_STATION
					WHEN [FundingTypeId] = @TORCH THEN @FUNDRAISING_ENTITY_TORCH_RELAY
					WHEN [FundingTypeId] = @DANCEDASH THEN @FUNDRAISING_ENTITY_DANCE_DASH
					WHEN [FundingTypeId] = @MIRACLECHALLENGE THEN @FUNDRAISING_ENTITY_MIRACLE_CHALLENGE
					ELSE [FundraisingEntityId]
				END
		WHERE [FundraisingEntityId] IS NULL AND [FundingGroupId] IN (@NATIONAL_PROGRAMS_GROUP, @NATIONAL_EVENT_GROUP);
		UPDATE @TempDisbursements SET [FundraisingEntityId] = @CMN_FUNDRAISING_ENTITY_ID WHERE [FundraisingEntityId] IS NULL;

		--Set the programId field for PlayYellow because we will be updating the Campaign Type to GOLF and we need a way to identify Play Yellow records
		UPDATE @TempDisbursements SET ProgramId = @PROGRAMID_PLAY_YELLOW WHERE [CampaignType] = 'Play Yellow'

		-- There are a few CampaignTypes that are named differently here compared to what is in Core.  We rename the affected ones so 
		-- that they can be looked up correctly
		UPDATE @TempDisbursements SET [CampaignType] = 'Miscellaneous' WHERE [CampaignType] = 'Misc.';
		UPDATE @TempDisbursements SET [CampaignType] = 'Canister' WHERE [CampaignType] = 'Coin Canister';
		UPDATE @TempDisbursements SET [CampaignType] = 'Icon' WHERE [CampaignType] = 'Icon Campaign';
		UPDATE @TempDisbursements SET [CampaignType] = 'Walk' WHERE [CampaignType] = 'Walk/Run';
		UPDATE @TempDisbursements SET [CampaignType] = 'Associate' WHERE [CampaignType] = 'RE/MAX Associate';
		UPDATE @TempDisbursements SET [CampaignType] = 'Golf' WHERE [CampaignType] = 'Play Yellow';

        -- Get the list of local direct mail entries
		INSERT INTO @LocalDirectMail ([Id])
			SELECT [Id]
			FROM @TempDisbursements
			WHERE [CampaignType] = 'Direct Mail' AND [FundingTypeId] = @LOCAL; 

        -- Get the list of all campaigns, along with their campaigntypeid
		INSERT INTO @Campaigns ([CampaignId], [CampaignName], [CampaignTypeId], [ProgramId])
			SELECT MAX([CampaignId]) AS [CampaignId], [CampaignName], [CampaignTypeId], [ProgramId] 
			FROM [Core].[dbo].[vwCampaignCompiledDetails] 
			GROUP BY [CampaignName], [CampaignTypeId], [ProgramId];

		-- Make sure we have an applicable Campaign record for each record (except radiothons/telethons/dance marathons/local direct mail and Corporate Partnerships- they should already exist) 
		INSERT INTO @NewCampaignDetails ([Name], [CampaignYear], [StartDate], [CampaignTypeId], [ProgramId])
			SELECT [EventName], [FundraisingYear], [DateReceived], [CampaignTypeId], [ProgramId] --there won't be a programId for any of this so set it to null
			FROM (
				SELECT DISTINCT td.[EventName], td.[FundraisingYear], td.[DateReceived], ct.[CampaignTypeId], td.ProgramId
				FROM @TempDisbursements td
					INNER JOIN [Core].[dbo].[vwCampaignTypes] ct ON td.[CampaignType]=ct.[CampaignType]
					LEFT OUTER JOIN @Campaigns c ON td.[EventName]=c.[CampaignName] AND ct.[CampaignTypeId]=c.[CampaignTypeId] AND COALESCE(td.[ProgramId], 0) = COALESCE(c.[ProgramId], 0)
				WHERE c.[CampaignId] IS NULL AND td.[FundingTypeId] NOT IN (@ENGLISHRADIOTHON, @HISPANICRADIOTHON, @TELETHON, @DANCEMARATHON,@CORPORATEPARTNERSHIPS) AND NOT EXISTS (SELECT * FROM @LocalDirectMail WHERE [Id] = td.[Id])) a;

		DECLARE @C_Id INT, @C_CampaignId INT, @C_Name VARCHAR(300), @C_CampaignYear INT, @C_StartDate DATETIME, @C_CampaignTypeId INT, @C_ProgramId INT

		WHILE (EXISTS(SELECT * FROM @NewCampaignDetails))
		BEGIN
			SELECT TOP(1) 
				@C_Id = [Id], 
				@C_Name = [Name],
				@C_CampaignYear = [CampaignYear], 
				@C_StartDate = [StartDate], 
				@C_CampaignTypeId = [CampaignTypeId],
				@C_ProgramId = [ProgramId]
			FROM @NewCampaignDetails 
			ORDER BY [Id];

			-- Insert records into the Campaigns table
			INSERT INTO @NewIds ([Id])
			EXEC [Core].[dbo].[spInsertCampaign] 
				@CampaignName = @C_Name,
				@LongDescription = @C_Name, 
				@ContactId = @ContactId;
			SELECT TOP(1) @C_CampaignId = [Id] FROM @NewIds ORDER BY [Id];

			PRINT 'Created a new campaign: ' + @C_Name + ' (ContactId = ' + CAST(@ContactId as varchar(10)) + ', CampaignId = ' + CAST(@C_CampaignId as varchar(10)) + ')'

			-- Insert records into the CampaignDetails table
			INSERT INTO @NewIds ([Id])
			EXEC [Core].[dbo].[spInsertCampaignDetail] 
				@CampaignId = @C_CampaignId,
				@CampaignDetailName = @C_Name, 
				@LongDescription = @C_Name, 
				@CampaignYear = @C_CampaignYear, 
				@LegacyEventId = '', 
				@StartDate = @C_StartDate, 
				@EndDate = @C_StartDate, 
				@CampaignTypeId = @C_CampaignTypeId, 
				@ContactId = @ContactId,
				@ProgramId = @C_ProgramId --if play yellow then 1 else null

			--PRINT 'Created a new campaign detail: ' + @C_Name + ' (CampaignId = ' + CAST(@C_CampaignId as varchar(10)) + ', CampaignYear = ' + CAST(@C_CampaignYear as varchar(10)) + ', ProgramId =' + CAST(@C_ProgramId as varchar(10))+ ')'

			-- Clean up temp records
			DELETE FROM @NewIds;
			DELETE FROM @NewCampaignDetails WHERE [Id] = @C_ID;
		END

		-- Make sure we have an applicable CampaignDetails record for each record (except radiothons/telethons/dance marathons and Corporate Partnerships- they should already exist; also, don't create local direct mail records here)
		INSERT INTO @NewCampaignDetails ([CampaignId], [Name], [CampaignYear], [StartDate], [CampaignTypeId], [ProgramId])
			SELECT [CampaignId], [EventName], [FundraisingYear], [DateReceived], [CampaignTypeId], [ProgramId]
			FROM (
				SELECT DISTINCT c.[CampaignId], td.[EventName], td.[FundraisingYear], td.[DateReceived], c.[CampaignTypeId], td.[ProgramId]
				FROM @TempDisbursements td
					INNER JOIN [Core].[dbo].[vwCampaignTypes] ct ON td.[CampaignType]=ct.[CampaignType]
					INNER JOIN @Campaigns c ON td.[EventName]=c.[CampaignName] AND ct.[CampaignTypeId]=c.[CampaignTypeId] AND COALESCE(td.[ProgramId], 0) = COALESCE(c.[ProgramId], 0)
					LEFT OUTER JOIN [Core].[dbo].[vwCampaignDetails] cd ON c.[CampaignId]=cd.[CampaignId] AND td.[FundraisingYear]=cd.[CampaignYear] AND ct.[CampaignTypeId]=cd.[CampaignTypeId] AND td.[EventName]=cd.[CampaignDetailName]
				WHERE cd.[CampaignDetailsId] IS NULL AND td.[FundingTypeId] NOT IN (@ENGLISHRADIOTHON, @HISPANICRADIOTHON, @TELETHON, @DANCEMARATHON,@CORPORATEPARTNERSHIPS) AND td.[Id] NOT IN (SELECT * FROM @LocalDirectMail)) a;

		-- Add CampaignDetails records for local direct mail records
		INSERT INTO @NewCampaignDetails ([CampaignId], [Name], [CampaignYear], [StartDate], [CampaignTypeId])
			SELECT [CampaignId], [EventName], [FundraisingYear], [DateReceived], [CampaignTypeId]
			FROM (
				SELECT DISTINCT @LOCAL_DIRECT_MAIL_CAMPAIGN_ID AS [CampaignId], td.[EventName], td.[FundraisingYear], td.[DateReceived], @CAMPAIGN_TYPE_ID_LOCAL AS [CampaignTypeId]
				FROM @TempDisbursements td
					INNER JOIN @LocalDirectMail ldm ON td.[Id] = ldm.[Id]
					LEFT OUTER JOIN (SELECT * FROM [Core].[dbo].[vwCampaignDetails] WHERE [CampaignId]=@LOCAL_DIRECT_MAIL_CAMPAIGN_ID) cd ON td.[FundraisingYear]=cd.[CampaignYear] AND td.[EventName]=cd.[CampaignDetailName]
				WHERE cd.[CampaignDetailsId] IS NULL) a;

		WHILE (EXISTS(SELECT * FROM @NewCampaignDetails))
		BEGIN
			SELECT TOP(1) 
				@C_Id = [Id], 
				@C_CampaignId = [CampaignId],
				@C_Name = [Name],
				@C_CampaignYear = [CampaignYear], 
				@C_StartDate = [StartDate], 
				@C_CampaignTypeId = [CampaignTypeId],
				@C_ProgramId = [ProgramId]
			FROM @NewCampaignDetails 
			ORDER BY [Id];

			-- Insert records into the CampaignDetails table
			INSERT INTO @NewIds ([Id])
			EXEC [Core].[dbo].[spInsertCampaignDetail] 
				@CampaignId = @C_CampaignId,
				@CampaignDetailName = @C_Name, 
				@LongDescription = @C_Name, 
				@CampaignYear = @C_CampaignYear, 
				@LegacyEventId = '', 
				@StartDate = @C_StartDate, 
				@EndDate = @C_StartDate, 
				@CampaignTypeId = @C_CampaignTypeId, 
				@ContactId = @ContactId,
				@ProgramId = @C_ProgramId; --These will not have a programId when <> Play Yellow
			--PRINT 'Created a new campaign detail: ' + @C_Name + ' (CampaignId = ' + CAST(@C_CampaignId as varchar(10)) + ', CampaignYear = ' + CAST(@C_CampaignYear as varchar(10)) + ')'

			-- Clean up temp records
			DELETE FROM @NewIds;
			DELETE FROM @NewCampaignDetails WHERE [Id] = @C_ID;
		END

		-- Get the CampaignDetailsId for the radiothon records
		UPDATE @TempDisbursements SET
			[CampaignDetailsId] = r.[CampaignDetailsId]
			FROM @TempDisbursements td
				INNER JOIN [dbo].[ExtendedEntries] ee ON td.[EntryId] = ee.[EntryId]
				INNER JOIN [Core].[dbo].[vwRadiothons] r ON CAST(ee.[Value] AS int) = r.[RadiothonId]
			WHERE ee.[Type] = 'Radiothon_KeyID' AND (td.[FundingTypeId] = @ENGLISHRADIOTHON OR td.[FundingTypeId] = @HISPANICRADIOTHON);

		-- Get the CampaignDetailsId for the dance marathon records
		UPDATE @TempDisbursements SET
			[CampaignDetailsId] = dm.[CampaignDetailsId]
			FROM @TempDisbursements td
				INNER JOIN [dbo].[ExtendedEntries] ee ON td.[EntryId] = ee.[EntryId]
				INNER JOIN [Core].[dbo].[vwDanceMarathons] dm ON CAST(ee.[Value] AS int) = dm.[DanceMarathonId]
			WHERE ee.[Type] = 'DanceMarathon_KeyID' AND (td.[FundingTypeId] = @DANCEMARATHON);

		-- Get the CampaignDetailsId for the telethon records
		UPDATE @TempDisbursements SET
			[CampaignDetailsId] = t.[CampaignDetailsId]
			FROM @TempDisbursements td
				INNER JOIN [dbo].[ExtendedEntries] ee ON td.[EntryId] = ee.[EntryId]
				INNER JOIN [Core].[dbo].[vwTelethons] t ON CAST(ee.[Value] AS int) = t.[TelethonId]
			WHERE ee.[Type] = 'Telethon_KeyID' AND (td.[FundingTypeId] = @TELETHON);

		-- Get the CampaignDetailsId for the local direct mail records
		UPDATE @TempDisbursements SET
			[CampaignDetailsId] = cd.[CampaignDetailsId]
			FROM @TempDisbursements td
				INNER JOIN @LocalDirectMail ldm ON td.[Id] = ldm.[Id]
				INNER JOIN (SELECT * FROM [Core].[dbo].[vwCampaignDetails] WHERE [CampaignId]=@LOCAL_DIRECT_MAIL_CAMPAIGN_ID) cd ON td.[FundraisingYear]=cd.[CampaignYear] AND td.[EventName]=cd.[CampaignDetailName];

		--Get the CampaignDetialsId for Corporate Partnerships
		UPDATE @TempDisbursements SET 
		   [CampaignDetailsId] = cd.[CampaignDetailsId]
		   FROM @TempDisbursements td
				INNER JOIN [dbo].[ExtendedEntries] ee ON td.[EntryId] = ee.[EntryId]
				INNER JOIN [Core].[dbo].[vwCampaignDetails] cd ON CAST(ee.[Value] AS INT) = cd.[CampaignDetailsId] 
		  WHERE ee.[Type] = 'Campaign_Details_Id';

		-- Get the CampaignDetailsId for the non-radiothon/non-telethon/non-dance marathon and non CorporatePartner records
		UPDATE @TempDisbursements SET
			[CampaignDetailsId] = t.[CampaignDetailsId]
			FROM @TempDisbursements td
				INNER JOIN (
					SELECT MAX([CampaignDetailsId]) AS [CampaignDetailsId], [CampaignYear], [CampaignDetailName], [CampaignType], [ProgramId]
					FROM [Core].[dbo].[vwCampaignCompiledDetails]
					GROUP BY [CampaignYear], [CampaignDetailName], [CampaignType], [ProgramId]
				) t ON td.[FundraisingYear]=t.[CampaignYear] AND td.[CampaignType]=t.[CampaignType] AND td.[EventName]=t.[CampaignDetailName] AND COALESCE(td.[ProgramId], 0) = COALESCE(t.[ProgramId], 0)
			WHERE (td.[FundingTypeId] <> @ENGLISHRADIOTHON AND td.[FundingTypeId] <> @HISPANICRADIOTHON AND td.[FundingTypeId] <> @TELETHON AND td.[FundingTypeId] <> @DANCEMARATHON AND td.FundingTypeId <> @CORPORATEPARTNERSHIPS);

		-- Make sure each temp disbursement record has a value for CampaignDetailsId
		IF ( EXISTS(SELECT * FROM @TempDisbursements WHERE [CampaignDetailsId] IS NULL) ) BEGIN
			RAISERROR (N'A worksheet record is missing a Campaign Details record. MarketWorksheetId: %d.', 18, -1, @MarketWorksheetId) WITH SETERROR;
		END

		-- Save data to Core
		DECLARE @D_RecordTypeId INT, @D_FundraisingEntityId INT, @D_FundraisingCategoryId INT, @D_MarketId INT, @D_DirectToHospital BIT, 
			@D_FundraisingYear INT, @D_Amount MONEY, @D_CurrencyTypeId INT, @D_CampaignDetailsId INT, @D_LocationId INT, @D_DateReceived DATE, 
			@D_DateRecorded DATE, @D_DonationDate DATE, @D_FundTypeId INT, @D_BatchId INT, @D_CampaignPeriod INT, @D_UploadId VARCHAR(20), 
			@D_Comment VARCHAR(300), @D_OverlapFundraisingEntityId VARCHAR(MAX), @D_FundTypeGUID UNIQUEIDENTIFIER, @D_PrimaryKey INT, @D_ID INT, @D_DisbursementId INT

		WHILE (EXISTS(SELECT * FROM @TempDisbursements WHERE [Inserted] = 0))
		BEGIN
			SELECT TOP(1) @D_RecordTypeId = [RecordTypeId], @D_FundraisingEntityId = [FundraisingEntityId], @D_FundraisingCategoryId = [FundraisingCategoryId], 
				@D_MarketId = [MarketId], @D_DirectToHospital = [DirectToHospital], @D_FundraisingYear = [FundraisingYear], 
				@D_Amount = [Amount], @D_CurrencyTypeId = [CurrencyTypeId],@D_CampaignDetailsId = [CampaignDetailsId], @D_LocationId = [LocationId], 
				@D_DateReceived = [DateReceived], @D_DateRecorded = [DateRecorded], @D_DonationDate = [DonationDate], @D_FundTypeId = [FundTypeId], 
				@D_BatchId = [BatchId], @D_CampaignPeriod = [CampaignPeriod], @D_UploadId = [UploadId], @D_Comment = [Comment],  
				@D_OverlapFundraisingEntityId = CAST([OverlapFundraisingEntityId] AS VARCHAR(MAX)), @D_FundTypeGUID = [FundTypeGUID], 
				@D_PrimaryKey = [PrimaryKey], @D_ID = [Id]
			FROM @TempDisbursements 
			WHERE [Inserted] = 0
			ORDER BY [Id];

			-- Insert records into the disbursements table
			INSERT INTO @NewIds ([Id])
			EXEC [Core].[dbo].[spInsertDisbursement] 
				@RecordTypeId = @D_RecordTypeId,
				@PrimaryFundraisingEntityId = @D_FundraisingEntityId,
				@FundraisingEntityId = @D_OverlapFundraisingEntityId,
				@MarketId = @D_MarketId,
				@DirectToHospital = @D_DirectToHospital,
				@FundraisingYear = @D_FundraisingYear,
				@Amount = @D_Amount,
				@CurrencyTypeId = @D_CurrencyTypeId,
				@CampaignDetailsId = @D_CampaignDetailsId,
				@LocationId = @D_LocationId,
				@DateReceived = @D_DateReceived,
				@DateRecorded = @D_DateRecorded,
				@DonationDate = @D_DonationDate,
				@FundTypeId = @D_FundTypeId,
				@BatchId = @D_BatchId,
				@CampaignPeriod = @D_CampaignPeriod,
				@UploadId = @D_UploadId,
				@Comment = @D_Comment,
				@DisbursementPeriodId = 0,
				@DisbursementDateId = 0,
				@FundraisingCategoryId = @D_FundraisingCategoryId,
				@CreatedBy = @ContactId;

			SELECT TOP(1) @D_DisbursementId = [Id] FROM @NewIds ORDER BY [Id];

			-- Copy the newly created DisbursementID values back into the associated records in the PartnerFunds and MiscFunds tables
			IF ( @D_FundTypeGUID = @PF_IDENTIFIER ) BEGIN
				UPDATE [dbo].[PartnerFunds] SET [DisbursementId] = @D_DisbursementId WHERE [PartnerFundId] = @D_PrimaryKey;
			END ELSE IF ( @D_FundTypeGUID = @MF_IDENTIFIER ) BEGIN
				UPDATE [dbo].[MiscFunds] SET [DisbursementId] = @D_DisbursementId WHERE [MiscFundId] = @D_PrimaryKey;
			END

			-- Clean up temp records
			DELETE FROM @NewIds;
			UPDATE @TempDisbursements SET [Inserted] = 1 WHERE [Id] = @D_ID;
		END

		--IF ( @TO_ADD_COUNT <> @ADDED_COUNT ) BEGIN
		--	RAISERROR (N'Disbursement record insert mismatch. MarketWorksheetId: %d.', 18, -1, @MarketWorksheetId) WITH SETERROR;
		--END

		-- Add pledge data to the temporary pledge data table
		INSERT INTO @TempPledgeData ([FundraisingEntityId], [MarketId], [FundraisingYear], [CampaignDetailsId], 
			[CurrencyTypeId], [Amount], [PledgeTypeId], [Quarter], [PledgeDate])
			SELECT 
				CASE 
					WHEN s.[FundingTypeId] IN (@ENGLISHRADIOTHON, @HISPANICRADIOTHON)
					THEN (SELECT TOP(1) [FundraisingEntityId] FROM @TempEntryRadioStations WHERE [EntryId] = e.[EntryId] ORDER BY [FundraisingEntityId])
					WHEN s.[FundingTypeId] = @TELETHON
					THEN (SELECT TOP(1) [FundraisingEntityId] FROM @TempEntryTvStations WHERE [EntryId] = e.[EntryId] ORDER BY [FundraisingEntityId])
				END AS [FundraisingEntityId],
				mw.[MarketId], 
				mw.[Year] AS [FundraisingYear],
				(SELECT TOP(1) [CampaignDetailsId] FROM [Core].[dbo].[vwCampaignDetails] WHERE [CampaignDetailName] = e.[EventName] AND [Campaignyear]=mw.[Year] ORDER BY [CampaignDetailsId]) AS [CampaignDetailsId],
				c.[CurrencyTypeId] AS [CurrencyTypeId],
				CAST(ee.[Value] AS MONEY) AS [Amount],
				CASE s.[FundingTypeId]
					WHEN @TELETHON
					THEN @PLEDGE_TYPE_HOSPITALTELETHONANNOUNCEDTOTAL
					ELSE @PLEDGE_TYPE_HOSPITALRADIOTHONANNOUNCEDTOTAL
				END AS [PledgeTypeId], 
				mw.[Quarter] AS [Quarter],
				CONVERT(DATETIME, (						-- Calculate the [PledgeDate] as the last day of the reporting quarter
					CASE mw.[Quarter] 
						WHEN 1 
						THEN '3/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 2 
						THEN '6/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						WHEN 3 
						THEN '9/30/' + CONVERT(VARCHAR(4), YEAR(GETDATE())) 
						ELSE '12/31/' + CONVERT(VARCHAR(4), YEAR(GETDATE()) - 1) 
					END)) AS [PledgeDate]
			FROM [dbo].[Marketworksheets] mw
				INNER JOIN [dbo].[Selections] s ON mw.[WorksheetId] = s.[WorksheetId]
				INNER JOIN [dbo].[Entries] e ON s.[SelectionId] = e.[SelectionId]
				INNER JOIN [dbo].[ExtendedEntries] ee ON e.[EntryId] = ee.[EntryId]
				INNER JOIN [Core].[dbo].[vwMarkets] m ON mw.[MarketId]=m.[MarketId]
				INNER JOIN [Core].[dbo].[vwCountries] c ON m.[CountryId]=c.[CountryId]
			WHERE mw.[WorksheetId] = @MarketWorksheetId AND ee.[Type] = 'Announced_Total'

		-- Calculate the adjusting amount for each pledge entry
		UPDATE @TempPledgeData SET
			[AdjustingAmount] = ISNULL(tpd.[Amount], 0) - ISNULL(pd.[Amount], 0)
		FROM @TempPledgeData tpd
			LEFT OUTER JOIN (
				SELECT [FundraisingEntityId], [MarketId], [CampaignDetailsId], SUM([Amount]) as [Amount], [PledgeTypeId]
				FROM [Core].[dbo].[vwPledgeDatas]
				GROUP BY [FundraisingEntityId], [MarketId], [CampaignDetailsId], [PledgeTypeId]) pd 
					ON tpd.[FundraisingEntityId] = pd.[FundraisingEntityId] 
						AND tpd.[MarketId] = pd.[MarketId]
						AND tpd.[CampaignDetailsId] = pd.[CampaignDetailsId] 
						AND tpd.[PledgeTypeId] = pd.[PledgeTypeId];

		-- remove records that would be created with a 0 amount
		DELETE FROM @TempPledgeData WHERE [AdjustingAmount] = 0;

		-- Copy the Announced Total data to the [Core].[dbo].[PledgeData] table
		DECLARE @PD_ID INT, @PD_FundraisingEntityId INT, @PD_MarketId INT, @PD_FundraisingYear INT, @PD_CampaignDetailsId INT, @PD_CurrencyTypeId INT, 
			@PD_PledgeTypeId INT, @PD_Quarter SMALLINT, @PD_PledgeDate DATE, @PD_AdjustingAmount MONEY

		WHILE (EXISTS(SELECT * FROM @TempPledgeData))
		BEGIN
			SELECT TOP(1) @PD_ID = [Id], @PD_FundraisingEntityId = [FundraisingEntityId], @PD_MarketId = [MarketId], @PD_FundraisingYear = [FundraisingYear], 
				@PD_CampaignDetailsId = [CampaignDetailsId], @PD_CurrencyTypeId = [CurrencyTypeId], @PD_PledgeTypeId = [PledgeTypeId], @PD_Quarter = [Quarter], 
				@PD_PledgeDate = [PledgeDate], @PD_AdjustingAmount = [AdjustingAmount]
			FROM @TempPledgeData
			ORDER BY [Id];

			-- Insert records into the pledgedata table
			INSERT INTO @NewIds ([Id])
			EXEC [Core].[dbo].[spInsertPledgeData]
				@FundraisingEntityId = @PD_FundraisingEntityId,
				@MarketId = @PD_MarketId,
				@FundraisingYear = @PD_FundraisingYear,
				@CampaignDetailsId = @PD_CampaignDetailsId,
				@CurrencyTypeId = @PD_CurrencyTypeId,
				@Amount = @PD_AdjustingAmount,
				@PledgeTypeId = @PD_PledgeTypeId,
				@Quarter = @PD_Quarter,
				@PledgeDate = @PD_PledgeDate,
				@DirectToHospital = 1,
				@CreatedBy = @ContactId;

			-- Clean up temp records
			DELETE FROM @NewIds;
			DELETE FROM @TempPledgeData WHERE [Id] = @PD_ID;
		END

		-- Update the MarketWorksheet table with the file date
		UPDATE [dbo].[MarketWorksheets]
		SET [LastModified] = GETDATE(), [FiledDate] = GETDATE(), [Filed] = 1, [Enabled] = 0
		WHERE [WorksheetId] = @MarketWorksheetId;

		COMMIT
	END TRY
	BEGIN CATCH
		-- We had an error so let's roll back all the records
		IF @@TRANCOUNT > 0
			ROLLBACK

		DECLARE @ErrorMessage NVARCHAR(4000),
				@ErrorSeverity INT

		SELECT
			@ErrorMessage = ERROR_MESSAGE(), 
			@ErrorSeverity = ERROR_SEVERITY();

		-- Raise the error that occured
		RAISERROR(@ErrorMessage, @ErrorSeverity, 1)

	END CATCH
END
GO

