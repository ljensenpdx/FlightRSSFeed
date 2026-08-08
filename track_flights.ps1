param([string]$flightsInput, [string]$outDir)

$flights = $flightsInput -split ','

$rssDir = Join-Path $outDir "RSS"
if (-not (Test-Path $rssDir)) {
    New-Item -ItemType Directory -Path $rssDir | Out-Null
}

$rssItems = ""
$pubDate = (Get-Date).ToString("R")

foreach ($f in $flights) {
    $parts = $f -split ':'
    $fileName = $parts[0]
    $userInput = $parts[1].ToUpper().Trim()
    
    $parsedFlight = $userInput
    $originAirport = "LAS"
    $timeOnly = "Time Not Found"
    
    if ($userInput -match '^([a-zA-Z]+)(\d+)$') {
        $alpha = $Matches[1]
        $digits = $Matches[2]
        
        $airlineMap = @{
            'WN' = 'SWA'
            'UA' = 'UAL'
            'DL' = 'DAL'
            'AA' = 'AAL'
            'B6' = 'JBU'
            'AS' = 'ASA'
            'NK' = 'NKS'
            'F9' = 'FFT'
            'HA' = 'HAL'
            'G4' = 'AAY'
            'SY' = 'SCX'
        }
        
        if ($airlineMap.ContainsKey($alpha)) {
            $faCode = $airlineMap[$alpha] + $digits
        } else {
            $faCode = "$alpha$digits"
        }
        
        $url = "https://flightaware.com/live/flight/$faCode"
        
        $chromePath = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
        $chromeUserPath = Join-Path $env:USERPROFILE 'AppData\Local\Google\Chrome\Application\chrome.exe'
        $edgePath = 'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
        $edgeUserPath = Join-Path $env:USERPROFILE 'AppData\Local\Microsoft\Edge\Application\msedge.exe'
        
        $targetBrowser = $null
        if (Test-Path $chromePath) { $targetBrowser = $chromePath }
        elseif (Test-Path $chromeUserPath) { $targetBrowser = $chromeUserPath }
        elseif (Test-Path $edgePath) { $targetBrowser = $edgePath }
        elseif (Test-Path $edgeUserPath) { $targetBrowser = $edgeUserPath }
        
        if ($targetBrowser) {
            $outImg = "$outDir\$fileName.png"
            $dumpHtml = "$outDir\$fileName.html"
            try {
                $argsList = "--headless=old --disable-gpu --run-all-compositor-stages-before-draw --screenshot=`"$outImg`" --dump-dom --window-size=1400,1800 $url"
                $process = Start-Process $targetBrowser -ArgumentList $argsList -RedirectStandardOutput $dumpHtml -PassThru
                Start-Sleep -Seconds 7
                if (!$process.HasExited) { $process.Kill() }
            } catch {}
        }

        if (Test-Path "$outDir\$fileName.html") {
            try {
                $html = Get-Content "$outDir\$fileName.html" -Raw
                
                if ($html -match 'flightPageIdent[^>]*>[\s\S]*?/&nbsp;([A-Z0-9]+)') {
                    $parsedFlight = $Matches[1].Trim()
                }
                if ($html -match 'flightPageSummaryAirportCode[^>]*>[\s\S]*?displayFlexElementContainer[^>]*>\s*([A-Z]{3})') {
                    $originAirport = $Matches[1].Trim()
                }
                if ($html -match 'flightPageSummaryArrival flightTime[^>]*>[\s\S]*?<em>\s*(\d{2}:\d{2}[AP]M)') {
                    $timeOnly = $Matches[1]
                }
            } catch {}
        }
    } else {
        $timeOnly = 'Invalid format'
    }
    
    # Each item links directly to the FlightAware page
    $rssItems += @"
    <item>
      <title>$parsedFlight from $originAirport arriving at $timeOnly</title>
      <link>$url</link>
      <description>$parsedFlight&#x0A;$originAirport&#x0A;$timeOnly</description>
      <pubDate>$pubDate</pubDate>
      <guid isPermaLink="true">$url</guid>
    </item>
"@
    
    Write-Host "Processed $fileName`: $parsedFlight | $originAirport | $timeOnly"
    Start-Sleep -Seconds 3
}

# Compile the single master RSS XML file containing all items
$masterRssContent = @"
<?xml version="1.0" encoding="UTF-8"?>
<rss version="2.0">
  <channel>
    <title>Active Flights Master Status Feed</title>
    <link>https://flightaware.com</link>
    <description>Unified live tracking feed for all shift flights</description>
    <language>en-us</language>
    <pubDate>$pubDate</pubDate>
$rssItems
  </channel>
</rss>
"@

$masterXmlFile = "$rssDir\all_flights.xml"
[IO.File]::WriteAllText($masterXmlFile, $masterRssContent)
Write-Host "Master RSS feed successfully updated at $masterXmlFile"