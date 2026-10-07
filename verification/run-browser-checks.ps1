param([int]$DebugPort = 9227, [int]$SitePort = 8080, [switch]$ScreenshotsOnly)
# Runs the existing HTML checks through Chrome's debugging protocol.
# Start serve.ps1 and a separate headless Chrome with remote debugging first.
$ErrorActionPreference = 'Stop'
$allTargets = Invoke-RestMethod "http://127.0.0.1:$DebugPort/json/list"
$testTarget = $allTargets | Where-Object { $_.type -eq 'page' -and ($_.url -eq 'about:blank' -or $_.url.StartsWith("http://127.0.0.1:$SitePort/")) } | Select-Object -First 1
if (-not $testTarget) { throw 'No blank test tab found in the debugging browser.' }
$testSocket = [Net.WebSockets.ClientWebSocket]::new()
$null = $testSocket.ConnectAsync([Uri]$testTarget.webSocketDebuggerUrl,[Threading.CancellationToken]::None).GetAwaiter().GetResult()
$script:commandId = 0
function Invoke-Cdp([string]$Method, [hashtable]$Parameters = @{}) {
    $script:commandId++
    $payload = @{id=$script:commandId; method=$Method; params=$Parameters} | ConvertTo-Json -Compress -Depth 30
    $bytes = [Text.Encoding]::UTF8.GetBytes($payload)
    $deadline = [Threading.CancellationTokenSource]::new(60000)
    try {
        $null = $testSocket.SendAsync([ArraySegment[byte]]::new($bytes),[Net.WebSockets.WebSocketMessageType]::Text,$true,$deadline.Token).GetAwaiter().GetResult()
        while ($true) {
            $buffer = New-Object byte[] 65536
            $message = [IO.MemoryStream]::new()
            do {
                $part = $testSocket.ReceiveAsync([ArraySegment[byte]]::new($buffer),$deadline.Token).GetAwaiter().GetResult()
                $message.Write($buffer,0,$part.Count)
            } until ($part.EndOfMessage)
            $reply = [Text.Encoding]::UTF8.GetString($message.ToArray()) | ConvertFrom-Json
            $message.Dispose()
            if ($reply.id -eq $script:commandId) {
                if ($reply.error) { throw $reply.error.message }
                return $reply.result
            }
        }
    } finally { $deadline.Dispose() }
}
function Get-Javascript([string]$Expression) {
    $reply = Invoke-Cdp 'Runtime.evaluate' @{expression=$Expression; returnByValue=$true; awaitPromise=$true}
    if ($reply.exceptionDetails) { throw ($reply.exceptionDetails | ConvertTo-Json -Depth 10) }
    return $reply.result.value
}
function Save-Screenshot([string]$Name, [hashtable]$Clip) {
    $parameters = @{format='png'; captureBeyondViewport=$true}
    if ($Clip.Count -gt 0) { $parameters.clip = $Clip }
    $shot = Invoke-Cdp 'Page.captureScreenshot' $parameters
    [IO.File]::WriteAllBytes((Join-Path $PSScriptRoot $Name),[Convert]::FromBase64String($shot.data))
}
try {
    $null = Invoke-Cdp 'Page.enable'
    $null = Invoke-Cdp 'Runtime.enable'
    $null = Invoke-Cdp 'Emulation.setDeviceMetricsOverride' @{width=1440;height=1080;deviceScaleFactor=1;mobile=$false}
    $summaries = @()
    if ($ScreenshotsOnly) {
        foreach ($suite in @('checks','motion','no-js')) {
            $savedDom = [IO.File]::ReadAllText((Join-Path $PSScriptRoot "$suite-dom.html"))
            $savedSummary = [regex]::Match($savedDom,'<h1 id="summary">([^<]+)</h1>').Groups[1].Value
            $savedResults = [Net.WebUtility]::HtmlDecode([regex]::Match($savedDom,'(?s)<pre id="results">(.*?)</pre>').Groups[1].Value) | ConvertFrom-Json
            $summaries += @{suite=$suite;summary=$savedSummary;total=@($savedResults).Count;failed=@($savedResults | Where-Object { -not $_.pass })}
        }
    } else {
    foreach ($suite in @('checks','motion','no-js')) {
        $motion = if ($suite -eq 'motion') { 'reduce' } else { 'no-preference' }
        $null = Invoke-Cdp 'Emulation.setEmulatedMedia' @{features=@(@{name='prefers-reduced-motion';value=$motion})}
        $checkFile = if ($suite -eq 'no-js') { 'no-js-checks.html' } else { 'checks.html' }
        $null = Invoke-Cdp 'Page.navigate' @{url="http://127.0.0.1:$SitePort/verification/$checkFile"}
        Start-Sleep -Milliseconds 600
        $timer = [Diagnostics.Stopwatch]::StartNew()
        do {
            $summary = Get-Javascript "document.querySelector('#summary')?.textContent || ''"
            if ($summary -match '^(PASS|FAIL)') { break }
            Start-Sleep -Milliseconds 500
        } while ($timer.Elapsed.TotalSeconds -lt 100)
        $resultsText = Get-Javascript "document.querySelector('#results')?.textContent || '[]'"
        $results = $resultsText | ConvertFrom-Json
        $failed = @($results | Where-Object { -not $_.pass })
        $summaries += @{suite=$suite;summary=$summary;total=@($results).Count;failed=$failed}
        Write-Output "$suite`: $summary"
        if ($failed.Count) { Write-Output ($failed | ConvertTo-Json -Depth 10) }
        [IO.File]::WriteAllText((Join-Path $PSScriptRoot "$suite-dom.html"),(Get-Javascript 'document.documentElement.outerHTML'),[Text.UTF8Encoding]::new($false))
    }
    }
    $null = Invoke-Cdp 'Emulation.setEmulatedMedia' @{features=@(@{name='prefers-reduced-motion';value='no-preference'})}
    $null = Invoke-Cdp 'Page.navigate' @{url="http://127.0.0.1:$SitePort/index.html"}
    Start-Sleep -Seconds 2
    $layouts = @()
    foreach ($width in @(375,768,1440)) {
        $null = Invoke-Cdp 'Emulation.setDeviceMetricsOverride' @{width=$width;height=1080;deviceScaleFactor=1;mobile=$false}
        $null = Get-Javascript "(async()=>{document.documentElement.style.scrollBehavior='auto';for(const element of document.querySelectorAll('#catapult .reveal')){element.scrollIntoView({block:'center',behavior:'instant'});await new Promise(resolve=>setTimeout(resolve,350));}document.querySelector('#catapult').scrollIntoView()})()"
        Start-Sleep -Seconds 1
        $measurements = Get-Javascript "(()=>{const section=document.querySelector('#catapult'),r=section.getBoundingClientRect(),photo=document.querySelector('.catapult-photo'),grid=document.querySelector('.catapult-layout');return {width:innerWidth,overflow:document.documentElement.scrollWidth>innerWidth,photoLoaded:photo.complete&&photo.naturalWidth>0,columns:getComputedStyle(grid).gridTemplateColumns,clip:{x:0,y:scrollY+r.top,width:innerWidth,height:r.height,scale:1}}})()"
        $layouts += $measurements
        $clip = @{}
        $measurements.clip.psobject.Properties | ForEach-Object { $clip[$_.Name]=$_.Value }
        Save-Screenshot "catapult-$width.png" $clip
        $null = Get-Javascript "(async()=>{for(const element of document.querySelectorAll('#in-the-box .reveal')){element.scrollIntoView({block:'center',behavior:'instant'});await new Promise(resolve=>setTimeout(resolve,350));}document.querySelector('#in-the-box').scrollIntoView()})()"
        Start-Sleep -Milliseconds 500
        $kitBounds = Get-Javascript "(()=>{const r=document.querySelector('#in-the-box').getBoundingClientRect();return {x:0,y:scrollY+r.top,width:innerWidth,height:r.height,scale:1}})()"
        $kitClip = @{}
        $kitBounds.psobject.Properties | ForEach-Object { $kitClip[$_.Name]=$_.Value }
        Save-Screenshot "kit-$width.png" $kitClip
        Write-Output "Layout $width`: overflow=$($measurements.overflow), photoLoaded=$($measurements.photoLoaded)"
    }
    $report = @{checkedOn='2026-10-07';browser='Chrome headless';suites=$summaries;catapultLayouts=$layouts;limitations=@('Physical touch input was not tested on a phone.','Public access to the supplied Google form is unconfirmed.')}
    [IO.File]::WriteAllText((Join-Path $PSScriptRoot 'results.json'),($report | ConvertTo-Json -Depth 20),[Text.UTF8Encoding]::new($false))
    if (@($summaries | Where-Object { $_.summary -notmatch '^PASS' }).Count -or @($layouts | Where-Object { $_.overflow -or -not $_.photoLoaded }).Count) { throw 'Browser verification failed; inspect results.json.' }
} finally { $testSocket.Dispose() }
