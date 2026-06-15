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

    # Start Docker Desktop if not running
    $dockerRunning = & $docker info 2>&1
    if ($LASTEXITCODE -ne 0) {
        Log "Docker Desktop not running -- starting it..."
        $desktopExe = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
        if (Test-Path $desktopExe) {
            Start-Process $desktopExe
            Log "Waiting 20s for Docker Desktop to start..."
            Start-Sleep -Seconds 20
        }
    }

    # Start the LLM stack
    Log "Starting Ollama + Open WebUI stack..."
    $result = & $docker compose -f "$devPath\docker-compose.yml" up -d 2>&1
    Log "docker compose: $($result -join ' ')"

    # Pull model if not already present
    $models = & $docker exec ollama ollama list 2>&1
    if ($models -notmatch "phi3") {
        Log "Pulling phi3:mini model (first run -- this may take a few minutes)..."
        Start-Process -FilePath $docker -ArgumentList "exec ollama ollama pull phi3:mini" -WindowStyle Normal
    } else {
        Log "phi3:mini model already present"
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
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$code`" `"$devPath`""
    Log "VS Code launched at: $devPath"
} else {
    Log "WARNING: VS Code not found"
}

Log "Developer launch complete"
Log "------------------------------------------------------"
