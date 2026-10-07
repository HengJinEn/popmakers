param([ValidateRange(1024,65535)][int]$Port = 8080)
# Minimal static server for Windows PowerShell. No installation or admin rights.
# Localhost only; GET/HEAD only; resolved paths must remain in this project.
$ErrorActionPreference = 'Stop'
$root = [System.IO.Path]::GetFullPath($PSScriptRoot)
$rootPrefix = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
$listener = [System.Net.Sockets.TcpListener]::new([System.Net.IPAddress]::Loopback,$Port)
$mimeTypes = @{ '.html'='text/html; charset=utf-8'; '.css'='text/css; charset=utf-8'; '.js'='text/javascript; charset=utf-8'; '.json'='application/json'; '.png'='image/png'; '.svg'='image/svg+xml'; '.glb'='model/gltf-binary'; '.ico'='image/x-icon'; '.md'='text/plain; charset=utf-8' }
try {
    $listener.Start()
    Write-Output "POP MAKERS is ready: http://127.0.0.1:$Port"
    Write-Output 'Keep this window open. Press Ctrl+C to stop.'
    while ($true) {
        $client = $listener.AcceptTcpClient()
        $stream = $null
        try {
            $stream = $client.GetStream()
            $stream.ReadTimeout = 5000
            $stream.WriteTimeout = 5000
            $request = [System.Text.StringBuilder]::new()
            # Read just through the headers, avoiding buffered data being lost.
            while ($request.Length -lt 16384) {
                $nextByte = $stream.ReadByte()
                if ($nextByte -eq -1) { break }
                [void]$request.Append([char]$nextByte)
                if ($request.ToString().EndsWith("`r`n`r`n")) { break }
            }
            $requestParts = ($request.ToString() -split "`r`n")[0] -split ' '
            $method = $requestParts[0]
            $statusCode = '200 OK'
            $contentType = 'text/plain; charset=utf-8'
            $body = [byte[]]@()
            if ($requestParts.Count -lt 2 -or $method -notin @('GET','HEAD')) {
                $statusCode = '405 Method Not Allowed'
                $body = [System.Text.Encoding]::UTF8.GetBytes('This preview server supports GET and HEAD only.')
            } else {
                $urlPath = [Uri]::UnescapeDataString(($requestParts[1] -split '\?')[0])
                if ($urlPath -eq '/') { $urlPath = '/index.html' }
                $relative = $urlPath.TrimStart([char[]]@('/','\')).Replace('/',[System.IO.Path]::DirectorySeparatorChar)
                $filePath = [System.IO.Path]::GetFullPath((Join-Path $root $relative))
                if (-not $filePath.StartsWith($rootPrefix,[StringComparison]::OrdinalIgnoreCase)) {
                    $statusCode = '403 Forbidden'
                    $body = [System.Text.Encoding]::UTF8.GetBytes('Path outside the project.')
                } elseif (-not [System.IO.File]::Exists($filePath)) {
                    $statusCode = '404 Not Found'
                    $body = [System.Text.Encoding]::UTF8.GetBytes('File not found.')
                } else {
                    $body = [System.IO.File]::ReadAllBytes($filePath)
                    $extension = [System.IO.Path]::GetExtension($filePath).ToLowerInvariant()
                    $contentType = if ($mimeTypes.ContainsKey($extension)) { $mimeTypes[$extension] } else { 'application/octet-stream' }
                }
            }
            $header = "HTTP/1.1 $statusCode`r`nContent-Type: $contentType`r`nContent-Length: $($body.Length)`r`nCache-Control: no-cache`r`nX-Content-Type-Options: nosniff`r`nConnection: close`r`n`r`n"
            $headerBytes = [System.Text.Encoding]::ASCII.GetBytes($header)
            $stream.Write($headerBytes,0,$headerBytes.Length)
            if ($method -ne 'HEAD') { $stream.Write($body,0,$body.Length) }
            $stream.Flush()
        } catch {
            # A browser can cancel requests while navigating. Continue serving.
            Write-Verbose $_.Exception.Message
        } finally {
            if ($stream) { $stream.Dispose() }
            $client.Close()
        }
    }
} finally { $listener.Stop() }
