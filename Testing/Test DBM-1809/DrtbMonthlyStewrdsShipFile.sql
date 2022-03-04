/*
RUN ON DonorNet.dn

DEV: RUN ON DonorNet.dnT1Dev

DRTVMonthlyStewardshipFle (C:\Github\SQL-Scripts\DonorNetQueries\zDRTV\DRTVMonthlyStewardshipFle.sql):
dbo.spPopulateDRTVMonthlyStewardshipFile
dbo.vwDRTVMonthlyStewardshipFile

AppealFileLoadSP (C:\Github\SQL-Scripts\DonorNetQueries\AckFiles\AppealFileLoadSP.sql):
EXEC adm.uspDonorAppealLoad 1 
no changes

New based on process:
dbo.AcknowledgementTypes
dbo.spInsertFilesToLoadRecord
dbo.spUpdateFilesToLoadRecord
dbo.spCleanupDRTVMonthlyStewardshipFile
dbo.spInsertDRTVFileInfo
dbo.spInsertDRTVMonthlyStewardshipFileDonorAppealLoad

Schedule:
2nd Monday of Every Month, 5am

Order of Operations:
* build DRTVMonthlyStewardshipFile data
* Insert FilesToLoad Record
* Cleanup DRTVMonthlyStewardshipFile data (take out monthly pledges, update appealId, update barcode, update scanline)
* Insert DRTVFileInfo record
* Insert DRTVMonthlyDonorAppealLoad record
* Run views to pull data and export to .txt/.csv
* Update FilesToLoad Record
* Run adm.uspDonorAppealLoad 1
*/
DROP TABLE IF EXISTS rpt.DRTVMonthlyStewardshipFile;
GO

CREATE TABLE rpt.DRTVMonthlyStewardshipFile
(
	Id					   INT,
	DonorId				   INT,
	Printname			   VARCHAR(55),
	Salutation			   VARCHAR(55),
	Companyname			   VARCHAR(75),
	Address1			   VARCHAR(55),
	Address2			   VARCHAR(55),
	City				   VARCHAR(40),
	[State]				   VARCHAR(40),
	Zip					   VARCHAR(10),
	email				   VARCHAR(100),
	PaymentDay			   VARCHAR(12),
	PledgeAmt			   MONEY,
	LastGiftDate		   VARCHAR(12),
	LastGiftAmt			   MONEY,
	AppealId			   INT,
	Barcode				   VARCHAR(30),
	Scanline			   VARCHAR(50),
	AckType				   INT,
	ChargeFrequency		   INT,
	TransactionType		   INT,
	CampaignId			   INT,
	HospitalId			   INT,
	CMNHospitalId		   INT,
	CMNHospitalName		   VARCHAR(125),
	PackageTypeId		   INT,
	SegmentTypeId		   INT,
	GiftMonth			   VARCHAR(25),
	GiftYear			   VARCHAR(4),
	Frequency			   VARCHAR(25),
	RecurringTransactionId INT
);
GO

CREATE OR ALTER PROCEDURE dbo.spPopulateDRTVMonthlyStewardshipFile
AS
	BEGIN

		DELETE FROM
		rpt.DRTVMonthlyStewardshipFile;

		WITH a AS
		(
			SELECT
			rt.donorID,
			rt.recurringTransactionID,
			rt.campaignID,
			rt.hospitalID,
			rt.donationAmount,
			rt.createdDateTime,
			rt.dayToCharge,
			rt.chargeFrequency,
			rt.transactionType,
			rt.CMNHospitalId,
			CAST(CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2)) + '/' + CAST(rt.dayToCharge AS VARCHAR(2)) + '/' + CAST(YEAR(GETDATE()) AS VARCHAR(4)) AS VARCHAR(12)) AS 'GiftDate'
			FROM
			dbo.recurringTransaction rt
			JOIN dbo.[campaign] c ON [c].[campaignID] = [rt].[campaignID]
			WHERE
			c.campaignTypeId = 8
			AND rt.deletedYN = 0
			AND rt.stopRecurringBillingYN = 0
			AND rt.activeDonor = 1
			AND DATEDIFF(MONTH, rt.createdDateTime, GETDATE()) >= 1
		),
			 b AS
		(
			SELECT
			t.donorID,
			t.recurringTransactionID,
			t.createdDateTime,
			t.donationAmount,
			RANK() OVER (PARTITION BY
						 t.recurringTransactionID
						 ORDER BY
						 t.donorTransactionID DESC
						) AS 'rnk'
			FROM
			a
			INNER JOIN dbo.donorTransaction t ON a.recurringTransactionID = t.recurringTransactionID
			WHERE
			t.resultCode = 0
			AND t.deletedYN = 0
			AND t.reversedYN = 0
			AND t.donationAmount > 0
			AND t.transactionType <> 4
		),
			 c AS
		(
			SELECT
			a.donorID,
			a.recurringTransactionID,
			a.campaignID,
			a.hospitalID,
			a.donationAmount AS 'PledgeAmt',
			CONVERT(VARCHAR(12), a.createdDateTime, 101) AS 'PledgeDate',
			a.GiftDate AS 'NextGiftDate',
			a.chargeFrequency,
			a.transactionType,
			a.CMNHospitalId,
			CONVERT(VARCHAR(12), b.createdDateTime, 101) AS 'LastGiftDate',
			b.donationAmount AS 'LastGiftAmt'
			FROM
			a
			INNER JOIN b ON a.recurringTransactionID = b.recurringTransactionID
			WHERE
			b.rnk = 1
		)
		/**/
		INSERT
		rpt.DRTVMonthlyStewardshipFile
		(Id, DonorId, Printname, Salutation, Companyname, Address1, Address2, City, State, Zip, email, PaymentDay, PledgeAmt, LastGiftDate, LastGiftAmt, AppealId, Barcode, Scanline, AckType, ChargeFrequency, TransactionType, CampaignId, HospitalId, CMNHospitalId, CMNHospitalName, PackageTypeId, SegmentTypeId, GiftMonth, GiftYear, Frequency, RecurringTransactionId)
		SELECT
		ROW_NUMBER() OVER (ORDER BY
						   c.donorID ASC,
						   c.recurringTransactionID ASC
						  ) Id,
		c.donorID, -- DonorId - int
		d.addressee, -- Printname - varchar(55)
		ISNULL(d.letterSalutation, 'Friend') Salutation, -- Salutation - varchar(55)
		d.companyName, -- Companyname - varchar(75)
		d.address1, -- Address1 - varchar(55)
		d.address2, -- Address2 - varchar(55)
		d.city, -- City - varchar(40)
		s.stateAbrev, -- State - varchar(40)
		d.postalCode, -- Zip - varchar(10)
		d.email, -- email - varchar(100)
		c.NextGiftDate, -- PaymentDay - varchar(12)
		c.PledgeAmt,
		c.LastGiftDate, -- LastGiftDate - varchar(12)
		c.LastGiftAmt, -- LastGiftAmt - money
		NULL AS 'AppealId', -- AppealId - int
		NULL AS 'Barcode', -- Barcode - varchar(30)
		NULL AS 'Scanline',
		NULL AS 'AckType', -- AckType - int
		c.chargeFrequency, -- ChargeFrequency - int
		c.transactionType, -- TransactionType - int
		c.campaignID, -- CampaignId - int
		c.hospitalID, -- HospitalId - int
		c.CMNHospitalId, -- CMNHospitalId - int
		h.HospitalName, -- HospitalName - varchar(125)
		1, -- PackageTypeId
		2, -- SegmentTypeId
		DATENAME(MONTH, DATEPART(MONTH, GETDATE())), -- GiftMonth
		CAST(YEAR(GETDATE()) AS VARCHAR(4)), -- GiftYear
		f.chargeFrequencyDescription,
		c.recurringTransactionID
		FROM
		c
		JOIN dbo.donor d ON c.donorID = d.donorID
		LEFT JOIN dbo.stateCodes s ON d.stateID = s.stateID
		JOIN dbo.cmnHospitals h ON c.CMNHospitalId = h.CMNHospitalId
		JOIN dbo.chargeFrequency f ON c.chargeFrequency = f.chargeFrequency
		WHERE
		d.sendAppealsTypeID = 0;
	END;
GO

CREATE OR ALTER VIEW dbo.vwDRTVMonthlyStewardshipFile
AS
	SELECT
	[Id],
	[DonorId],
	[Printname],
	[Salutation],
	[Companyname],
	[Address1],
	[Address2],
	[City],
	[State],
	[Zip],
	[email],
	[PaymentDay],
	[PledgeAmt],
	[LastGiftDate],
	[LastGiftAmt],
	[AppealId],
	[Barcode],
	[Scanline],
	[AckType],
	[ChargeFrequency],
	[TransactionType],
	[CampaignId],
	[HospitalId],
	[CMNHospitalId],
	[CMNHospitalName],
	[PackageTypeId],
	[SegmentTypeId],
	[GiftMonth],
	[GiftYear],
	[Frequency],
	[RecurringTransactionId]
	FROM
	rpt.DRTVMonthlyStewardshipFile;
GO

CREATE OR ALTER PROCEDURE dbo.spInsertFilesToLoadRecord
(
	@TotalRecords  INT,
	@FilesToLoadId INT = NULL OUTPUT
)
AS
	BEGIN
		DECLARE @NewAppealIdMin INT =
				(
					SELECT
					MAX(EndNum) + 1
					FROM
					intranet.FilesToLoad
				);
		DECLARE @NewAppealIdMax INT = (@NewAppealIdMin + @TotalRecords);

		INSERT INTO
		[intranet].[FilesToLoad]
		([StartNum], [EndNum], [File], [Status], [CampaignId], [Qty], [Check], [Mailed])
		VALUES
		(@NewAppealIdMin, -- StartNum - int
		 @NewAppealIdMax, -- EndNum - int
		 CONCAT('DRTV ', FORMAT(GETDATE(), 'MMMM'), ' ', YEAR(GETDATE()), ' Stewardship Files'), -- File - nvarchar(255)
		 'not in', -- Status - nvarchar(255)
		 NULL, -- CampaignId - nvarchar(255)
		 @TotalRecords, -- Qty - int
		 NULL, -- Check - int
		 NULL -- Mailed - datetime2(0)
		);

		SET @FilesToLoadId = @@IDENTITY;
	END;
GO

CREATE OR ALTER PROCEDURE dbo.spUpdateFilesToLoadRecord
(
	@FilesToLoadId INT,
	@Status		   VARCHAR(255),
	@CampaignId	   VARCHAR(255),
	@Check		   INT,
	@Mailed		   DATETIME
)
AS
	BEGIN
		UPDATE
		[intranet].[FilesToLoad]
		SET
		[Status] = @Status,
		[CampaignId] = @CampaignId,
		[Check] = @Check,
		[Mailed] = @Mailed
		WHERE
		[Id] = @FilesToLoadId;
	END;
GO

CREATE OR ALTER PROCEDURE dbo.spInsertDRTVFileInfo
(
	@MaxRecTransId		 INT,
	@MaxAppealId		 INT,
	@FileType			 INT,
	@FileTypeDescription VARCHAR(50),
	@FileQty			 INT
)
AS
	BEGIN
		INSERT INTO
		rpt.[DRTVFileInfo]
		([MaxRecTransId], [MaxAppealId], [FileType], [FileTypeDescription], [FileDate], [FileQty])
		VALUES
		(@MaxRecTransId, -- MaxRecTransId - int
		 @MaxAppealId, -- MaxAppealId - int
		 @FileType, -- FileType - int
		 @FileTypeDescription, -- FileTypeDescription - varchar(50)
		 GETDATE(), -- FileDate - smalldatetime
		 @FileQty -- FileQty - int
		);
	END;
GO

CREATE OR ALTER PROCEDURE dbo.spCleanupDRTVMonthlyStewardshipFile
AS
	BEGIN
		--take out monthly pledges, [TransactionType] = 4, [ChargeFrequency] = 2
		DELETE FROM
		rpt.DRTVMonthlyStewardshipFile
		WHERE
		[TransactionType] = 4
		AND [ChargeFrequency] = 2;

		--update acktype
		UPDATE
		rpt.DRTVMonthlyStewardshipFile
		SET
		[AckType] = CASE
						WHEN [email] IS NULL
							 AND [ChargeFrequency] = 2 THEN 34
						WHEN [email] IS NULL
							 AND [ChargeFrequency] = 1 THEN 35
						WHEN [email] IS NOT NULL
							 AND [ChargeFrequency] = 2 THEN 36
						WHEN [email] IS NOT NULL
							 AND [ChargeFrequency] = 1 THEN 37
						ELSE NULL
					END;

		--update AppealId
		DECLARE @TotalRecords INT =
				(
					SELECT
					COUNT(*)
					FROM
					rpt.[DRTVMonthlyStewardshipFile]
				);
		DECLARE @MinAppealId INT;
		DECLARE @FilesToLoadId INT;

		IF @TotalRecords > 0
		BEGIN
			EXEC dbo.[spInsertFilesToLoadRecord]
			@TotalRecords,
			@FilesToLoadId;
		END

		SELECT
		@MinAppealId = StartNum
		FROM
		[intranet].[FilesToLoad]
		WHERE
		[Id] = @FilesToLoadId;

		--Return PK From dbo.spInsertFilesToLoadRecord
		SELECT
		ISNULL(@FilesToLoadId,0) [FilesToLoadId],
		'In' [Status],
		ISNULL((SELECT TOP 1 [CampaignId] FROM rpt.[DRTVMonthlyStewardshipFile]),0) [CampaignId],
		@TotalRecords [Check],
		GETDATE() + 7 [Mailed]

		UPDATE
		rpt.[DRTVMonthlyStewardshipFile]
		SET
		[AppealId] = ((@MinAppealId - 1) + Id)
		WHERE
		[AppealId] IS NULL;

		--update Barcode
		UPDATE
		rpt.[DRTVMonthlyStewardshipFile]
		SET
		[Barcode] = CONCAT('*', [AppealId], '*')
		WHERE
		[Barcode] IS NULL;

		--update Scanline
		UPDATE
		rpt.[DRTVMonthlyStewardshipFile]
		SET
		[Scanline] = CONCAT([DonorId], '_', [AppealId])
		WHERE
		[Scanline] IS NULL;

		--Insert DRTVFileInfo record
		DECLARE @MaxRecTransId INT =
				(
					SELECT
					MAX([RecurringTransactionId])
					FROM
					rpt.[DRTVMonthlyStewardshipFile]
				);
		DECLARE @MaxAppealId INT =
				(
					SELECT
					MAX(EndNum)
					FROM
					intranet.[FilesToLoad]
					WHERE
					[Id] = @FilesToLoadId
				);
		DECLARE @FileDate SMALLDATETIME = GETDATE();
		
		IF @TotalRecords > 0
		BEGIN
			EXEC dbo.spInsertDRTVFileInfo
			@MaxRecTransId,
			@MaxAppealId,
			4,
			'Monthly Stewardship File',
			@FileDate,
			@TotalRecords;
		END
	END;
GO

CREATE OR ALTER PROCEDURE dbo.spInsertDRTVMonthlyStewardshipFileDonorAppealLoad
AS
	BEGIN
		DELETE FROM
		zzz.[donorAppealLoad];

		INSERT INTO
		zzz.[donorAppealLoad]
		([donorAppealID], [donorID], [campaignID], [hospitalID], [prospectID], [recurringTransactionID], [ackType], [appealAmount], [segmentTypeID], [packageTypeID], [listCode], [mailDateTime], [oldCkcId], [oldDnId], [appealDescription], [multiBuyer], [Split], [var1], [var2], [var3], [Salutation], [costPerPiece], [dateTimeInserted])
		SELECT
		a.[AppealId], -- donorAppealID - bigint
		a.[DonorId], -- donorID - int
		a.[CampaignId], -- campaignID - int
		a.[HospitalId], -- hospitalID - int
		NULL, -- prospectID - bigint
		a.[RecurringTransactionId], -- recurringTransactionID - int
		a.[AckType], -- ackType - smallint
		a.[PledgeAmt], -- appealAmount - money
		a.[SegmentTypeId], -- segmentTypeID - int
		a.[PackageTypeId], -- packageTypeID - int
		NULL, -- listCode - varchar(5)
		GETDATE() + 7, -- mailDateTime - datetime
		NULL, -- oldCkcId - bigint
		NULL, -- oldDnId - bigint
		c.[campaignName], -- appealDescription - varchar(75)
		NULL, -- multiBuyer - bit
		NULL, -- Split - smallint
		NULL, -- var1 - int
		NULL, -- var2 - int
		NULL, -- var3 - int
		a.[Salutation], -- Salutation - varchar(75)
		0, -- costPerPiece - money
		GETDATE() -- dateTimeInserted - datetime
		FROM
		dbo.[vwDRTVMonthlyStewardshipFile] a
		JOIN [dbo].[campaign] c ON [c].[CampaignId] = [a].[CampaignId];
	END;
GO

CREATE OR ALTER VIEW dbo.vwDRTVMonthlyDonorStewardshipLetter
AS
	--Donor email is null and chargefrequency = 2
	--Mail Files to be sent to SL Mail/Attention Paul Naylor/CC JASturz
	--COMMA SEPERATED .TXT FILE Double Quotes with Headers

	SELECT
	[sf].[Id],
	[sf].[DonorId],
	[sf].[CampaignId],
	[sf].[HospitalId],
	[sf].[Printname],
	[sf].[Salutation],
	[sf].[Companyname],
	[sf].[Address1],
	[sf].[Address2],
	[sf].[City],
	[sf].[State],
	[sf].[Zip],
	[sf].[AckType],
	[sf].[PaymentDay],
	[sf].[PledgeAmt],
	[sf].[LastGiftDate],
	[sf].[LastGiftAmt],
	[sf].[GiftMonth],
	[sf].[GiftYear],
	[sf].[Frequency],
	[sf].[CMNHospitalId],
	[sf].[CMNHospitalName],
	[sf].[AppealId],
	[sf].[Barcode],
	[sf].[Scanline]
	FROM
	dbo.vwDRTVMonthlyStewardshipFile sf
	WHERE
	[sf].[email] IS NULL
	AND [sf].[ChargeFrequency] = 2;
GO

CREATE OR ALTER VIEW dbo.vwDRTVOneTimeDonorStewardshipLetter
AS
	--Donor email is null and chargefrequency = 1
	--Mail Files to be sent to SL Mail/Attention Paul Naylor/CC JASturz
	--COMMA SEPERATED .TXT FILE Double Quotes with Headers

	SELECT
	[sf].[Id],
	[sf].[DonorId],
	[sf].[CampaignId],
	[sf].[HospitalId],
	[sf].[Printname],
	[sf].[Salutation],
	[sf].[Companyname],
	[sf].[Address1],
	[sf].[Address2],
	[sf].[City],
	[sf].[State],
	[sf].[Zip],
	[sf].[AckType],
	[sf].[PaymentDay],
	[sf].[PledgeAmt],
	[sf].[LastGiftDate],
	[sf].[LastGiftAmt],
	[sf].[GiftMonth],
	[sf].[GiftYear],
	[sf].[Frequency],
	[sf].[CMNHospitalId],
	[sf].[CMNHospitalName],
	[sf].[AppealId],
	[sf].[Barcode],
	[sf].[Scanline]
	FROM
	dbo.vwDRTVMonthlyStewardshipFile sf
	WHERE
	[sf].[email] IS NULL
	AND [sf].[ChargeFrequency] = 1;
GO

CREATE OR ALTER VIEW dbo.vwDRTVDonorStewardshipLetter
AS
	--Mail Files to be sent to SL Mail/Attention Paul Naylor/CC JASturz
	--COMMA SEPERATED .TXT FILE Double Quotes with Headers

	SELECT
	[Id],
	[DonorId],
	[CampaignId],
	[HospitalId],
	[Printname],
	[Salutation],
	[Companyname],
	[Address1],
	[Address2],
	[City],
	[State],
	[Zip],
	[AckType],
	[PaymentDay],
	[PledgeAmt],
	[LastGiftDate],
	[LastGiftAmt],
	[GiftMonth],
	[GiftYear],
	[Frequency],
	[CMNHospitalId],
	[CMNHospitalName],
	[AppealId],
	[Barcode],
	[Scanline]
	FROM
	dbo.vwDRTVMonthlyDonorStewardshipLetter
	UNION ALL
	SELECT
	[Id],
	[DonorId],
	[CampaignId],
	[HospitalId],
	[Printname],
	[Salutation],
	[Companyname],
	[Address1],
	[Address2],
	[City],
	[State],
	[Zip],
	[AckType],
	[PaymentDay],
	[PledgeAmt],
	[LastGiftDate],
	[LastGiftAmt],
	[GiftMonth],
	[GiftYear],
	[Frequency],
	[CMNHospitalId],
	[CMNHospitalName],
	[AppealId],
	[Barcode],
	[Scanline]
	FROM
	dbo.vwDRTVOneTimeDonorStewardshipLetter;

GO

CREATE OR ALTER VIEW dbo.vwDRTVMonthlyDonorStewardshipEmail
AS
	--Donor email is not null and chargefrequency = 2
	--Email Files should be sent to Adam Denison, Vivian Kwok / CC JASturz
	--COMMA SEPERATED .CSV FILE Double Quotes with Headers

	SELECT
	[sf].[Id],
	[sf].[DonorId],
	[sf].[CampaignId],
	[sf].[HospitalId],
	[sf].[Printname],
	[sf].[Salutation],
	[sf].[Companyname],
	[sf].[Address1],
	[sf].[Address2],
	[sf].[City],
	[sf].[State],
	[sf].[Zip],
	[sf].[AckType],
	[sf].[PaymentDay],
	[sf].[PledgeAmt],
	[sf].[LastGiftDate],
	[sf].[LastGiftAmt],
	[sf].[GiftMonth],
	[sf].[GiftYear],
	[sf].[Frequency],
	[sf].[CMNHospitalId],
	[sf].[CMNHospitalName],
	[sf].[AppealId],
	[sf].[Barcode],
	[sf].[Scanline]
	FROM
	dbo.vwDRTVMonthlyStewardshipFile sf
	WHERE
	[sf].[email] IS NOT NULL
	AND [sf].[email] <> ''
	AND [sf].[ChargeFrequency] = 2;
GO

CREATE OR ALTER VIEW dbo.vwDRTVOneTimeDonorStewardshipEmail
AS
	--Donor email is not null and chargefrequency = 1
	--Email Files should be sent to Adam Denison, Vivian Kwok / CC JASturz
	--COMMA SEPERATED .CSV FILE Double Quotes with Headers

	SELECT
	[sf].[Id],
	[sf].[DonorId],
	[sf].[CampaignId],
	[sf].[HospitalId],
	[sf].[Printname],
	[sf].[Salutation],
	[sf].[Companyname],
	[sf].[Address1],
	[sf].[Address2],
	[sf].[City],
	[sf].[State],
	[sf].[Zip],
	[sf].[AckType],
	[sf].[PaymentDay],
	[sf].[PledgeAmt],
	[sf].[LastGiftDate],
	[sf].[LastGiftAmt],
	[sf].[GiftMonth],
	[sf].[GiftYear],
	[sf].[Frequency],
	[sf].[CMNHospitalId],
	[sf].[CMNHospitalName],
	[sf].[AppealId],
	[sf].[Barcode],
	[sf].[Scanline]
	FROM
	dbo.vwDRTVMonthlyStewardshipFile sf
	WHERE
	[sf].[email] IS NOT NULL
	AND [sf].[email] <> ''
	AND [sf].[ChargeFrequency] = 1;
GO