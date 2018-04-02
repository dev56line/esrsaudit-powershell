@echo off
set FILENAME="Flagfile_Gateway2.flg"
if exist %FILENAME% (goto FILE_EXIST) else goto :FILE_NOT_EXIST

:FILE_EXIST
echo "Flag File for ESRS#2 is found."
echo "Delete Flag files and enabling audit..."
goto DELETE_FLAG

:FILE_NOT_EXIST
echo "Flag File for ESRS#2 is not created in current directory."
echo "Auditing is already enabled...Nothing to do."
goto BATCH_END

:DELETE_FLAG
del %FILENAME% 2>&1 | find /v ""
if %ERRORLEVEL%==1 (
   goto BATCH_END
) else (
   goto ERROR
)

:BATCH_END
exit 0

:ERROR
exit 1
