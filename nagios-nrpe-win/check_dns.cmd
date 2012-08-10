@ECHO OFF
SETLOCAL
SET SCRIPTNAME=%~n0
IF "%1"=="" ECHO Incorrect Syntax - use: %SCRIPTNAME% IPaddress or @File_Of_IPaddresses && GOTO :END
Set Param=%1
If not "%Param:~0,1%"=="@" GoTo :RUN
rem Echo. Reading IP addresses from %Param:~1%
For /F %%a in (%Param:~1%) Do (
Call :RUN %%a)
rem Echo. List completed
GoTo :EOF

:RUN
FOR /F "tokens=3delims=: " %%I IN ('PING -n 1 %1 ^| FIND "Reply from"') DO (
SET IP=%%I
FOR /F "tokens=2 delims=:" %%J IN ('NSLOOKUP %%I set-your-dns-server-ip ^| FIND "Name:"') DO SET DNS=%%J
)
IF NOT DEFINED IP @ECHO CRITICAL - %1 is invalid or NETWORK error occurred. && GOTO :END
rem ECHO.
IF NOT DEFINED DNS @ECHO CRITICAL - %1 - invalid DNS name or DNS error occurred. && GOTO :END

rem echo %TIME%
rem echo %DNS%
rem ECHO.%DNS%
rem pause
ECHO OK - DNS seems to be operational.
exit 0

:: Finish with error (CRITICAL)
:END
rem pause
exit 2