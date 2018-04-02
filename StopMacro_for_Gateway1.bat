@echo off
set FILENAME="Flagfile_Gateway1.flg"
if exist %FILENAME% (goto FILE_EXIST) else goto :FILE_NOT_EXIST

:FILE_EXIST
echo "Flag File for ESRS#1 is found."
echo "Audit is already disabled...Nothing to do."
goto BATCH_END

:FILE_NOT_EXIST
echo "Flag File for ESRS#1 is not created in current directory."
echo "Create Flag file and disabling audit..."
goto CREATE_FLAG

:CREATE_FLAG
(type nul > %FILENAME%) 2>&1 | find /v ""
if %ERRORLEVEL%==1 (
   goto BATCH_END
) else (
   goto ERROR
)

:BATCH_END
exit 0

:ERROR
exit 1
