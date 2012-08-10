@ECHO OFF
SETLOCAL
:: Store start time
FOR /f "tokens=1-4 delims=:.," %%T IN ("%TIME%") DO (
SET StartTIME=%TIME%
SET /a Start100S=%%T*360000+%%U*6000+%%V*100+%%W
)

:: Main Batch code goes here
:: First, let's check if domain name have been set as param while executing script
FOR /F "tokens=3delims=: " %%I IN ('PING -n 1 %1 ^| FIND "Reply from"') DO (
SET IP=%%I
FOR /F "tokens=2 delims=:" %%J IN ('NSLOOKUP %%I 127.0.0.1 ^| FIND "Name:"') DO SET DNS=%%J
)
IF NOT DEFINED IP @ECHO CRITICAL - %1 is invalid or NETWORK error occurred.
IF NOT DEFINED IP GOTO :cri
ECHO.
IF NOT DEFINED DNS @ECHO CRITICAL - %1 - invalid DNS name or DNS error occurred. && GOTO :cri
IF NOT DEFINED DNS GOTO :cri

:: Retrieve Stop time
FOR /f "tokens=1-4 delims=:.," %%T IN ("%TIME%") DO (
SET StopTIME=%TIME%
SET /a Stop100S=%%T*360000+%%U*6000+%%V*100+%%W
)

:: Test midnight rollover. If so, add 1 day=8640000 1/100ths secs
IF %Stop100S% LSS %Start100S% SET /a Stop100S+=8640000
SET /a TookTime=%Stop100S%-%Start100S%

:OK
ECHO OK - (%~nx0) Elapsed: %TookTime:~0,-2%.%TookTime:~-2% seconds|time=%TookTime:~0,-2%.%TookTime:~-2%s;;;;
exit 0

:cri
echo CRITICAL
exit 2