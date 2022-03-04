WITH a AS
         (
             SELECT rt.donorID,
                    rt.recurringTransactionID,
                    rt.campaignID,
                    rt.hospitalID,
                    rt.donationAmount,
                    rt.createdDateTime,
                    rt.dayToCharge,
                    rt.chargeFrequency,
                    rt.transactionType,
                    rt.CMNHospitalId,
                    CAST(CAST(DATEPART(MONTH, GETDATE()) AS VARCHAR(2)) + '/' + CAST(rt.dayToCharge AS VARCHAR(2)) +
                         '/' + CAST(YEAR(GETDATE()) AS VARCHAR(4)) AS VARCHAR(12)) AS 'GiftDate'
             FROM dbo.recurringTransaction rt
                      JOIN dbo.[campaign] c ON [c].[campaignID] = [rt].[campaignID]
             WHERE c.campaignTypeId = 8
               AND rt.deletedYN = 0
               AND rt.stopRecurringBillingYN = 0
               AND rt.activeDonor = 1
               AND DATEDIFF(MONTH, rt.createdDateTime, GETDATE()) >= 1
             and rt.donorID IN (2422052,
                    2422053)
         ),
     b AS
         (
             SELECT t.donorID,
                    t.recurringTransactionID,
                    t.createdDateTime,
                    t.donationAmount,
                    RANK() OVER (PARTITION BY
                        t.recurringTransactionID
                        ORDER BY
                            t.donorTransactionID DESC
                        ) AS 'rnk'
             FROM a
                      INNER JOIN dbo.donorTransaction t ON a.recurringTransactionID = t.recurringTransactionID
             WHERE t.resultCode = 0
               AND t.deletedYN = 0
               AND t.reversedYN = 0
               AND t.donationAmount > 0
               AND t.transactionType <> 4
         ),
      c AS
         (
             SELECT a.donorID,
                    a.recurringTransactionID,
                    a.campaignID,
                    a.hospitalID,
                    a.donationAmount                             AS 'PledgeAmt',
                    CONVERT(VARCHAR(12), a.createdDateTime, 101) AS 'PledgeDate',
                    a.GiftDate                                   AS 'NextGiftDate',
                    a.chargeFrequency,
                    a.transactionType,
                    a.CMNHospitalId,
                    CONVERT(VARCHAR(12), b.createdDateTime, 101) AS 'LastGiftDate',
                    b.donationAmount                             AS 'LastGiftAmt'
             FROM a
                      INNER JOIN b ON a.recurringTransactionID = b.recurringTransactionID
             WHERE b.rnk = 1
         )

-- select  * from a,b,c



    /**/
-- 		INSERT
-- 		rpt.DRTVMonthlyStewardshipFile
-- 		(Id, DonorId, Printname, Salutation, Companyname, Address1, Address2, City, State, Zip, email, PaymentDay, PledgeAmt, LastGiftDate, LastGiftAmt, AppealId, Barcode, Scanline, AckType, ChargeFrequency, TransactionType, CampaignId, HospitalId, CMNHospitalId, CMNHospitalName, PackageTypeId, SegmentTypeId, GiftMonth, GiftYear, Frequency, RecurringTransactionId)
SELECT ROW_NUMBER() OVER (ORDER BY
    c.donorID ASC,
    c.recurringTransactionID ASC
    )                                       Id,
       c.donorID,                                       -- DonorId - int
       d.addressee,                                     -- Printname - varchar(55)
       ISNULL(d.letterSalutation, 'Friend') Salutation, -- Salutation - varchar(55)
       d.companyName,                                   -- Companyname - varchar(75)
       d.address1,                                      -- Address1 - varchar(55)
       d.address2,                                      -- Address2 - varchar(55)
       d.city,                                          -- City - varchar(40)
       s.stateAbrev,                                    -- State - varchar(40)
       d.postalCode,                                    -- Zip - varchar(10)
       d.email,                                         -- email - varchar(100)
       c.NextGiftDate,                                  -- PaymentDay - varchar(12)
       c.PledgeAmt,
       c.LastGiftDate,                                  -- LastGiftDate - varchar(12)
       c.LastGiftAmt,                                   -- LastGiftAmt - money
       NULL AS                              'AppealId', -- AppealId - int
       NULL AS                              'Barcode',  -- Barcode - varchar(30)
       NULL AS                              'Scanline',
       NULL AS                              'AckType',  -- AckType - int
       c.chargeFrequency,                               -- ChargeFrequency - int
       c.transactionType,                               -- TransactionType - int
       c.campaignID,                                    -- CampaignId - int
       c.hospitalID,                                    -- HospitalId - int
       c.CMNHospitalId,                                 -- CMNHospitalId - int
       h.HospitalName,                                  -- HospitalName - varchar(125)
       1,                                               -- PackageTypeId
       2,                                               -- SegmentTypeId
       DATENAME(MONTH, DATEPART(MONTH, GETDATE())),     -- GiftMonth
       CAST(YEAR(GETDATE()) AS VARCHAR(4)),             -- GiftYear
       f.chargeFrequencyDescription,
       c.recurringTransactionID
FROM c
         JOIN dbo.donor d ON c.donorID = d.donorID
         JOIN dbo.stateCodes s ON d.stateID = s.stateID
         JOIN dbo.cmnHospitals h ON c.CMNHospitalId = h.CMNHospitalId
    JOIN dbo.chargeFrequency f ON c.chargeFrequency = f.chargeFrequency
WHERE d.sendAppealsTypeID = 0
  and d.donorID IN (2422052,
                    2422053)



