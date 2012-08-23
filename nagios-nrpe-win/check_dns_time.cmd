@ECHO OFF
SETLOCAL
:: Store start time
rem echo %TIME%
set HH=%TIME:~0,2%
set MM=%TIME:~3,-6%
set SS=%TIME:~6,-3%
set MS=%TIME:~9%

IF "%HH:~0,1%"=="0" SET HH=%HH:~1%
IF "%MM:~0,1%"=="0" SET MM=%MM:~1%
IF "%SS:~0,1%"=="0" SET SS=%SS:~1%
IF "%MS:~0,1%"=="0" SET MS=%MS:~1%

SET /A Start100S=%HH%*360000+%MM%*6000+%SS%*100+%MS%

:: Main Batch code goes here
:: First, let's check if domain name have been set as param while executing script
FOR /F "tokens=3delims=: " %%I IN ('PING -n 1 %1 ^| FIND "Reply from"') DO (
SET IP=%%I
FOR /F "tokens=2 delims=:" %%J IN ('NSLOOKUP %%I set-your-dns-server-ip ^| FIND "Name:"') DO SET DNS=%%J
)
IF NOT DEFINED IP @ECHO CRITICAL - %1 is invalid or NETWORK error occurred.
IF NOT DEFINED IP GOTO :cri
IF NOT DEFINED DNS @ECHO CRITICAL - %1 - invalid DNS name or DNS error occurred. && GOTO :cri
IF NOT DEFINED DNS GOTO :cri

:: Retrieve Stop time
set HH=%TIME:~0,2%
set MM=%TIME:~3,-6%
set SS=%TIME:~6,-3%
set MS=%TIME:~9%

IF "%HH:~0,1%"=="0" SET HH=%HH:~1%
IF "%MM:~0,1%"=="0" SET MM=%MM:~1%
IF "%SS:~0,1%"=="0" SET SS=%SS:~1%
IF "%MS:~0,1%"=="0" SET MS=%MS:~1%

SET /a Stop100S=%HH%*360000+%MM%*6000+%SS%*100+%MS%

:: Test midnight rollover. If so, add 1 day=8640000 1/100ths secs
IF %Stop100S% LSS %Start100S% SET /a Stop100S+=8640000
SET /a TookTime=%Stop100S%-%Start100S%

:OK
if %TookTime% LSS 100 (set TookTime=0%TookTime:~0,-2%.%TookTime:~-2%) else (set TookTime=%TookTime:~0,-2%.%TookTime:~-2%)

ECHO OK - (%~nx0) Elapsed: %TookTime% seconds^|time=%TookTime%s;;;;
exit 0

:cri
exit 2