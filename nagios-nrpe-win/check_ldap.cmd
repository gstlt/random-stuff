@ECHO OFF
SETLOCAL
SET SCRIPTNAME=%~n0
IF "%1"=="" ECHO Incorrect Syntax - use: %SCRIPTNAME% First_Name Last_Name && GOTO :END
IF "%2"=="" ECHO Incorrect Syntax - use: %SCRIPTNAME% First_Name Last_Name && GOTO :END

:RUN
FOR /F "tokens=3delims=: " %%I IN ('cscript C:\scripts\ldap\queryad.vbs -u "%1 %2" ^| FIND "Found 1 objects"') DO (
SET USER=%%I
)
IF NOT DEFINED USER @ECHO CRITICAL - %1 %2 is invalid or NETWORK error occurred. && GOTO :END

rem pause
ECHO OK - LDAP seems to be operational.
exit 0

:: Finish with error (CRITICAL)
:END
rem pause
exit 2
