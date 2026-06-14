# setup-logon-task.ps1
# Run via Intune as SYSTEM (Run as logged-on user = No)
# Registers a scheduled task that fires at every user login in their own session.

$scriptDir  = "C:\ProgramData\DevOpsDemo"
$scriptPath = "$scriptDir\logon-sync.ps1"

New-Item -ItemType Directory -Force -Path $scriptDir | Out-Null
icacls $scriptDir /grant "Users:(RX)" /T | Out-Null

# Write the sync script to shared location
$syncScript = @'
$repoUrl  = "https://github.com/Contoso-M365x635/devops-demo.git"
$repoPath = "$env:USERPROFILE\Projects\devops-demo"
$logFile  = "$env:USERPROFILE\Projects\devops-sync.log"

New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Projects" | Out-Null

function Log($msg) {
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $logFile -Value $entry
}

Log "======================================================"
Log "Logon sync started | User: $env:USERNAME | Machine: $env:COMPUTERNAME"

# Clone or Pull
if (Test-Path "$repoPath\.git") {
    Log "Repo exists -- pulling latest..."
    $result = git -C $repoPath pull origin main 2>&1
    Log "git pull: $($result -join ' ')"
} else {
    Log "First login -- cloning repo..."
    $result = git clone $repoUrl $repoPath 2>&1
    Log "git clone: $($result -join ' ')"
}

# Read user map from repo config
$configFile = "$repoPath\config\user-map.json"
$folder = $repoPath
if (Test-Path $configFile) {
    try {
        $config    = Get-Content -Path $configFile -Raw | ConvertFrom-Json
        $upn       = try { (whoami /upn 2>&1) -join "" } catch { "" }
        $upnPrefix = if ($upn -like "*@*") { ($upn -split "@")[0] } else { $env:USERNAME }
        $match     = $null
        if ($config.users.($env:USERNAME))             { $match = $config.users.($env:USERNAME) }
        elseif ($config.users.$upnPrefix)              { $match = $config.users.$upnPrefix }
        elseif ($config.default -and $config.default -ne "") { $match = $config.default }
        if ($match) { $folder = Join-Path $repoPath ($match -replace "/","\"); Log "Mapped to: $match" }
        else        { Log "No mapping -- opening repo root" }
    } catch { Log "Config error: $_" }
}

# Launch VS Code
$code = $null
if     (Get-Command "code" -ErrorAction SilentlyContinue)                            { $code = "code" }
elseif (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd")       { $code = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" }
elseif (Test-Path "C:\Program Files\Microsoft VS Code\bin\code.cmd")                 { $code = "C:\Program Files\Microsoft VS Code\bin\code.cmd" }

if ($code) { Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$code`" `"$folder`""; Log "VS Code launched: $folder" }
else       { Log "VS Code not found" }

Log "Logon sync complete"
Log "======================================================"
'@

Set-Content -Path $scriptPath -Value $syncScript -Encoding UTF8

# Remove old task if it exists
Unregister-ScheduledTask -TaskName "DevOps Demo - Repo Sync on Login" -Confirm:$false -ErrorAction SilentlyContinue

# Build task XML — uses InteractiveToken so it runs as whoever logs in
$taskXml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.3" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>DevOps Demo - Clone or sync repo on user login and open VS Code</Description>
  </RegistrationInfo>
  <Triggers>
    <LogonTrigger>
      <Enabled>true</Enabled>
    </LogonTrigger>
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
    <AllowHardTerminate>true</AllowHardTerminate>
    <StartWhenAvailable>false</StartWhenAvailable>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-ExecutionPolicy Bypass -WindowStyle Hidden -File "C:\ProgramData\DevOpsDemo\logon-sync.ps1"</Arguments>
    </Exec>
  </Actions>
</Task>
"@

# Register using XML — S-1-5-4 is the "Interactive" built-in SID (any logged-on user)
Register-ScheduledTask -Xml $taskXml -TaskName "DevOps Demo - Repo Sync on Login" -Force | Out-Null

Write-Host "Setup complete. Task registered for all interactive users."
Write-Host "Script location: $scriptPath"
