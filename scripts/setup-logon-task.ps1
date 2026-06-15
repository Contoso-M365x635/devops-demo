# setup-logon-task.ps1
# ─────────────────────────────────────────────────────────────────────────────
# Run via Intune as SYSTEM (Run as logged-on user = No)
# Deploys a universal logon launcher to C:\ProgramData\DevOpsDemo\
# and registers a scheduled task that fires at every user login.
#
# The launcher reads config/user-map.json from the repo to decide:
#   - Which folder to open in VS Code
#   - Which launch script to run (logon-sync or developer-launch)
# ─────────────────────────────────────────────────────────────────────────────

$scriptDir     = "C:\ProgramData\DevOpsDemo"
$launcherPath  = "$scriptDir\launcher.ps1"

New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
icacls $scriptDir /grant "Users:(RX)" /T | Out-Null

# ── Universal launcher — written to shared location ───────────────────────────
$launcher = @'
# launcher.ps1 — Universal login launcher
# Reads user-map.json, syncs repo, then calls the right per-role script.

$repoUrl  = "https://github.com/Contoso-M365x635/devops-demo.git"
$repoPath = "$env:USERPROFILE\Projects\devops-demo"
$logFile  = "$env:USERPROFILE\Projects\devops-sync.log"

New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Projects" | Out-Null

function Log($msg) {
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $logFile -Value $entry
}

Log "======================================================"
Log "Launcher started | User: $env:USERNAME | Machine: $env:COMPUTERNAME"

# ── Resolve git ───────────────────────────────────────────────────────────────
$git = $null
foreach ($p in @("C:\Program Files\Git\bin\git.exe","C:\Program Files\Git\cmd\git.exe","C:\Program Files (x86)\Git\bin\git.exe")) {
    if (Test-Path $p) { $git = $p; break }
}
if (-not $git) { $git = (Get-Command git -ErrorAction SilentlyContinue)?.Source }

# ── Clone or Pull ─────────────────────────────────────────────────────────────
if ($git) {
    if (Test-Path "$repoPath\.git") {
        Log "Repo exists -- pulling latest..."
        $result = & $git -C $repoPath pull origin main 2>&1
        Log "git pull: $($result -join ' ')"
    } else {
        Log "First login -- cloning repo..."
        $result = & $git clone $repoUrl $repoPath 2>&1
        Log "git clone: $($result -join ' ')"
    }
} else {
    # Fallback: download ZIP if git not installed
    Log "git not found -- downloading ZIP..."
    $zipUrl  = "https://github.com/Contoso-M365x635/devops-demo/archive/refs/heads/main.zip"
    $zipPath = "$env:TEMP\devops-demo.zip"
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath -UseBasicParsing
        if (Test-Path $repoPath) {
            Expand-Archive -Path $zipPath -DestinationPath "$env:TEMP\devops-refresh" -Force
            Copy-Item "$env:TEMP\devops-refresh\devops-demo-main\*" $repoPath -Recurse -Force
            Remove-Item "$env:TEMP\devops-refresh" -Recurse -Force
            Log "Repo refreshed from ZIP"
        } else {
            Expand-Archive -Path $zipPath -DestinationPath "$env:USERPROFILE\Projects" -Force
            Rename-Item "$env:USERPROFILE\Projects\devops-demo-main" $repoPath
            Log "Repo extracted from ZIP"
        }
        Remove-Item $zipPath -Force
    } catch { Log "ZIP download failed: $_" }
}

# ── Read user map ─────────────────────────────────────────────────────────────
$configFile = "$repoPath\config\user-map.json"
$launchScript = $null
$folder       = $repoPath

if (Test-Path $configFile) {
    try {
        $config    = Get-Content -Path $configFile -Raw | ConvertFrom-Json
        $upn       = try { (whoami /upn 2>&1) -join "" } catch { "" }
        $upnPrefix = if ($upn -like "*@*") { ($upn -split "@")[0] } else { $env:USERNAME }

        $mapping = $null
        if ($config.users.($env:USERNAME))  { $mapping = $config.users.($env:USERNAME) }
        elseif ($config.users.$upnPrefix)   { $mapping = $config.users.$upnPrefix }
        elseif ($config.users.$upn)         { $mapping = $config.users.$upn }

        if ($mapping) {
            if ($mapping.folder -and $mapping.folder -ne "") {
                $folder = Join-Path $repoPath ($mapping.folder -replace "/","\")
            }
            if ($mapping.launch -and $mapping.launch -ne "") {
                $launchScript = Join-Path $repoPath ($mapping.launch -replace "/","\")
            }
            Log "Mapped '$env:USERNAME' → folder: $($mapping.folder) | launch: $($mapping.launch)"
        } else {
            Log "No mapping for '$env:USERNAME' -- using defaults"
        }
    } catch { Log "Config error: $_" }
} else {
    Log "WARNING: user-map.json not found"
}

# ── Run role-specific launch script if defined ────────────────────────────────
if ($launchScript -and (Test-Path $launchScript)) {
    Log "Running launch script: $launchScript"
    & powershell.exe -ExecutionPolicy Bypass -File $launchScript
} else {
    # Default: just open VS Code at mapped folder
    $code = $null
    if     (Get-Command "code" -ErrorAction SilentlyContinue)                            { $code = "code" }
    elseif (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd")       { $code = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" }
    elseif (Test-Path "C:\Program Files\Microsoft VS Code\bin\code.cmd")                 { $code = "C:\Program Files\Microsoft VS Code\bin\code.cmd" }

    if ($code) {
        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$code $folder`""
        Log "VS Code launched at: $folder"
    } else {
        Log "WARNING: VS Code not found"
    }
}

Log "Launcher complete"
Log "======================================================"
'@

Set-Content -Path $launcherPath -Value $launcher -Encoding UTF8

# ── Remove old task and re-register ──────────────────────────────────────────
Unregister-ScheduledTask -TaskName "DevOps Demo - Repo Sync on Login" -Confirm:$false -ErrorAction SilentlyContinue

$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>DevOps Demo - Universal login launcher for all demo user roles</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger><Enabled>true</Enabled></LogonTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <GroupId>S-1-5-4</GroupId>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT10M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\DevOpsDemo\launcher.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

Register-ScheduledTask -Xml $taskXml -TaskName "DevOps Demo - Repo Sync on Login" -Force | Out-Null

# Grant Users permission to run/read the task
try {
    $scheduler = New-Object -ComObject Schedule.Service
    $scheduler.Connect()
    $task = $scheduler.GetFolder("\").GetTask("DevOps Demo - Repo Sync on Login")
    $sddl = $task.GetSecurityDescriptor(4)
    $newSddl = $sddl + "(A;;GRGX;;;BU)"
    $task.SetSecurityDescriptor($newSddl, 0)
    Write-Host "User permissions granted on task"
} catch { Write-Host "Note: Could not set task SDDL: $_" }

Write-Host "Setup complete!"
Write-Host "Launcher: $launcherPath"
Write-Host "User map: edit $env:USERPROFILE\Projects\devops-demo\config\user-map.json"

