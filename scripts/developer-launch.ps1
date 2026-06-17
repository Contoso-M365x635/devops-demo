# developer-launch.ps1
# Starts the local LLM stack (Ollama + Open WebUI via Docker)
# and opens VS Code at the developer environment folder.
# Called by the scheduled task on login for Developer users.

$repoPath = "$env:USERPROFILE\Projects\devops-demo"
$devPath  = "$repoPath\developer"
$logFile  = "$env:USERPROFILE\Projects\devops-sync.log"

function Log($msg) {
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $logFile -Value $entry
}

Log "------------------------------------------------------"
Log "Developer launch started | User: $env:USERNAME"

# ── Resolve Docker ────────────────────────────────────────────────────────────
$docker = $null
$dockerPaths = @(
    "C:\Program Files\Docker\Docker\resources\bin\docker.exe",
    "C:\Program Files\Docker\Docker\Docker Desktop.exe"
)
if (Get-Command docker -ErrorAction SilentlyContinue) { $docker = "docker" }
else {
    foreach ($p in $dockerPaths) { if (Test-Path $p) { $docker = $p; break } }
}

if (-not $docker) {
    Log "ERROR: Docker not found"
} else {
    Log "Using docker: $docker"

    # Start Docker Desktop and wait for it to be fully ready
    Log "Checking Docker readiness..."
    $dockerReady = $false
    for ($i = 0; $i -lt 30; $i++) {
        $dockerRunning = & $docker info 2>&1
        if ($LASTEXITCODE -eq 0) {
            Log "Docker is ready"
            $dockerReady = $true
            break
        }
        if ($i -eq 0) {
            Log "Docker not ready -- starting Docker Desktop..."
            $desktopExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
            if (Test-Path $desktopExe) {
                Start-Process $desktopExe
            }
        }
        Log "Waiting for Docker... (attempt $($i + 1) of 30)"
        Start-Sleep -Seconds 2
    }
    if (-not $dockerReady) {
        Log "WARNING: Docker still not ready after 60s -- proceeding anyway"
    }

    # Start the LLM stack
    Log "Starting Ollama + Open WebUI stack..."
    $result = & $docker compose -f "$devPath\docker-compose.yml" up -d 2>&1
    Log "docker compose: $($result -join ' ')"

    # Pull models for Arena (needs 2+ models)
    $models = & $docker exec ollama ollama list 2>&1
    $modelList = $models -join ' '

    if ($modelList -notmatch "phi3") {
        Log "Pulling phi3:mini (Model 1 for Arena)..."
        & $docker exec ollama ollama pull phi3:mini 2>&1 | ForEach-Object { Log "ollama: $_" }
    } else {
        Log "phi3:mini already present"
    }

    if ($modelList -notmatch "gemma2") {
        Log "Pulling gemma2:2b (Model 2 for Arena)..."
        # Pull in background so login doesn't block -- model available once download completes
        Start-Process -FilePath $docker -ArgumentList "exec ollama ollama pull gemma2:2b" -WindowStyle Normal
        Log "gemma2:2b download started in background (~1.6GB)"
    } else {
        Log "gemma2:2b already present"
    }

    # Wait for Open WebUI to be ready then open browser
    Log "Waiting for Open WebUI to be ready..."
    $ready = $false
    for ($i = 0; $i -lt 12; $i++) {
        Start-Sleep -Seconds 5
        try {
            $resp = Invoke-WebRequest -Uri "http://localhost:3000" -TimeoutSec 3 -UseBasicParsing -ErrorAction SilentlyContinue
            if ($resp.StatusCode -eq 200) { $ready = $true; break }
        } catch {}
    }

    if ($ready) {
        Start-Process "http://localhost:3000"
        Log "Open WebUI launched in browser: http://localhost:3000"
    } else {
        Log "WARNING: Open WebUI not ready after 60s -- opening anyway"
        Start-Process "http://localhost:3000"
    }
}

# ── Launch VS Code at developer folder ────────────────────────────────────────
$code = $null
if     (Get-Command "code" -ErrorAction SilentlyContinue)                            { $code = "code" }
elseif (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd")       { $code = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" }
elseif (Test-Path "C:\Program Files\Microsoft VS Code\bin\code.cmd")                 { $code = "C:\Program Files\Microsoft VS Code\bin\code.cmd" }

if ($code) {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$code $devPath`""
    Log "VS Code launched at: $devPath"
} else {
    Log "WARNING: VS Code not found"
}

Log "Developer launch complete"
Log "------------------------------------------------------"
