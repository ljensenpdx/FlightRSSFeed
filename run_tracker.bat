@echo off
cd /d "C:\Users\lanej\OneDrive\Desktop\Flights"

:loop
cls
echo ========================================================
echo [%DATE% %TIME%] Starting Flight Tracker Update...
echo ========================================================

:: Run the PowerShell tracking script
powershell -ExecutionPolicy Bypass -File "track_flights.ps1" -flightsInput "Flight01:WN237,Flight02:WN2603" -outDir "C:\Users\lanej\OneDrive\Desktop\Flights"

echo.
echo --------------------------------------------------------
echo [%TIME%] Committing and pushing updates to GitHub...
echo --------------------------------------------------------

:: Git commands to stage, commit, and push the XML update
git add RSS\all_flights.xml
git commit -m "Auto-update flight status: %DATE% %TIME%"
git push origin main

echo.
echo ========================================================
echo [%TIME%] Update complete! Waiting 5 minutes for next cycle...
echo ========================================================

:: Wait 300 seconds (5 minutes) before running again
timeout /t 300 /nobreak > nul
goto loop