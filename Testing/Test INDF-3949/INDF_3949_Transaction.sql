CREATE PROCEDURE [dbo].[INDF_3949_Transaction]
           @FileName			  VARCHAR(255),
           @UserContactId		  INT,
           @BatchNumber		  VARCHAR(25),
           @RecordTypeId		  INT,
           @FundraisingYear	  INT,
           @DirectToHospitalFlag BIT,
           @Foundation			  BIT,
           @BatchTypeId		  INT,
           @UploadId			  VARCHAR(20)
           WITH RECOMPILE
           AS
           	BEGIN
           		SET NOCOUNT ON;

           		/* Assign values to variables */
           		DECLARE @RecordCount INT =
           				(
           					SELECT
           					COUNT(LineNumber)
           					FROM
           					TemporaryData.dbo.TempRTD
           					WHERE
           					BatchNumber = @BatchNumber
           				);
           		DECLARE @BatchAmount MONEY =
           				(
           					SELECT
           					SUM(Amount)
           					FROM
           					TemporaryData.dbo.TempRTD
           					WHERE
           					BatchNumber = @BatchNumber
           				);
           		DECLARE @BatchId INT;
           		DECLARE @ErrorMessage VARCHAR(MAX);
           		DECLARE @ErrorSeverity INT;
           		DECLARE @ErrorState INT;
           		DECLARE @RTDFileUploaderLogId INT;
           		DECLARE @LogDate DATETIME =
           				(
           					SELECT
           					GETDATE()
           				);
           		DECLARE @CreditCardFees MONEY =
           				(
           					SELECT
           					SUM(DonorPaidCreditCardFees)
           					FROM
           					TemporaryData.dbo.TempRTD
           					WHERE
           					BatchNumber = @BatchNumber
           				);

           		/* insert record into dbo.RTDFileUploaderLog table for error logging */
           		INSERT INTO
           		TemporaryData.dbo.RTDFileUploaderLog
           		(FileName, BatchNumber, StartDate, RecordCount, CreatedBy)
           		VALUES
           		(@FileName, @BatchNumber, GETDATE(), @RecordCount, @UserContactId);
           		SET @RTDFileUploaderLogId = SCOPE_IDENTITY();

           		/* This Procedure always starts with validating the File has all the data in the correct format by running spRTDDisbursementErrors, if the file doesn't pass validation this procedure stops at this step */
           		BEGIN TRY
           			BEGIN TRAN errorLogging;
           			EXEC TemporaryData.dbo.spRTDDisbursementErrors
           			@FileName,
           			@UserContactId,
           			@BatchNumber,
           			@LogDate,
           			@FundraisingYear;
           			COMMIT TRAN errorLogging;
           		END TRY
           		BEGIN CATCH
           			IF @@TRANCOUNT > 0
           				ROLLBACK TRAN errorLogging;

           			--ErrorLogging
           			SET @ErrorMessage = ERROR_MESSAGE();
           			SET @ErrorSeverity = ERROR_SEVERITY();
           			SET @ErrorState = ERROR_STATE();

           		END CATCH;

           		IF @ErrorMessage IS NULL
           			BEGIN
           				/* If the file fails validation we update RTDFileUploaderLog with pertinent information  */
           				IF EXISTS
           				(
           					SELECT TOP (1)
           						   RTDUploadLogId
           					FROM
           					Core.dbo.RTDUploadLog
           					WHERE
           					BatchNumber = @BatchNumber
           					AND LogDate = @LogDate
           				)
           					BEGIN
           						UPDATE
           						TemporaryData.dbo.RTDFileUploaderLog
           						SET
           						EndDate = GETDATE(),
           						Success = 0,
           						Error = 'File failed validatation, please check Core.dbo.RTDLog for further details.'
           						WHERE
           						RTDFileUploaderLogId = @RTDFileUploaderLogId;
           					END;
           					ELSE
           					BEGIN
           						BEGIN TRY
           							BEGIN TRAN;

           							EXEC TemporaryData.dbo.spRTDInsertBatchRecord
           							@BatchNumber,
           							@Foundation,
           							@BatchTypeId,
           							@BatchId OUTPUT;

           							EXEC TemporaryData.dbo.spRTDInsertDisbursement
           							@FileName,
           							@UserContactId,
           							@BatchNumber,
           							@BatchId,
           							@RecordTypeId,
           							@FundraisingYear,
           							@DirectToHospitalFlag,
           							@Foundation,
           							@BatchTypeId,
           							@UploadId;
           							/* dbo.spRTDInsertDisbursement also runs dbo.spRTDInsertDisbursementDonor*/

           							/* if all the insert stored procedures complete successfully, a success message is inserted into the RTDLog table */
           							EXEC Core.dbo.spRTDLogRecordInsert
           							@FileName,
           							@BatchNumber,
           							@LogDate,
           							@UserContactId,
           							1,
           							NULL,
           							@BatchAmount,
           							@RecordCount,
           							1,
           							@CreditCardFees; -- RTDLogMessageId of 1 is 'Disbursements table updated successfully', RTDLogTypeId of 1 'Disbursement'

           							UPDATE
           							TemporaryData.dbo.RTDFileUploaderLog
           							SET
           							EndDate = GETDATE(),
           							Success = 1
           							WHERE
           							RTDFileUploaderLogId = @RTDFileUploaderLogId;

           							COMMIT TRAN;
           						END TRY
           						BEGIN CATCH

           							IF @@TRANCOUNT > 0
           								ROLLBACK TRAN;

           							--ErrorLogging
           							SET @ErrorMessage = ERROR_MESSAGE();
           							SET @ErrorSeverity = ERROR_SEVERITY();
           							SET @ErrorState = ERROR_STATE();

           						END CATCH;
           					END;
           			END;


           		/* DELETE FROM THE TEMP TABLE ANY DATA BELONGING TO THE BATCH NUMBER THE STORED PROCEDURE IS CURRENTLY RUNNING ON */
           		DELETE FROM
           		TemporaryData.dbo.TempRTD
           		WHERE
           		BatchNumber = @BatchNumber;

           		IF @ErrorMessage IS NOT NULL
           		BEGIN
           						UPDATE
           							TemporaryData.dbo.RTDFileUploaderLog
           							SET
           							EndDate = GETDATE(),
           							Success = 0,
           							Error = @ErrorMessage
           							WHERE
           							RTDFileUploaderLogId = @RTDFileUploaderLogId;

           		RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
           		END;
           	END;
go

