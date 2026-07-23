# install-developer-tools.ps1
# Install mobile development tools for Developer Cloud PC (MeganBowen)
# Installs: Android Studio, scrcpy (phone mirror), ADB platform-tools
# Deploy via Intune as SYSTEM

$logFile = "C:\ProgramData\Intune\install-developer-tools.log"

function Log($msg) {
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $logFile -Value $entry
}

Log "=================================================="
Log "Installing Developer tools: Android Studio + scrcpy"
Log "=================================================="

$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Log "ERROR: winget not found. Cannot proceed."
    exit 1
}

Log "winget version: $(& winget --version)"

# ── Android Studio ─────────────────────────────────────────────────────────
Log "Installing Android Studio..."
$asResult = & winget install --id Google.AndroidStudio --accept-source-agreements --accept-package-agreements 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "SUCCESS: Android Studio installed"
} else {
    Log "WARNING: Android Studio install exit code $LASTEXITCODE -- $($asResult -join ' ')"
}

# ── ADB Platform Tools (standalone, lighter than full SDK) ─────────────────
# Android Studio includes ADB, but install standalone too so ADB is in PATH
Log "Installing Android Platform Tools (ADB)..."
$adbResult = & winget install --id Google.PlatformTools --accept-source-agreements --accept-package-agreements 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "SUCCESS: ADB Platform Tools installed"
} else {
    Log "WARNING: ADB install exit code $LASTEXITCODE -- $($adbResult -join ' ')"
}

# ── scrcpy (phone screen mirror over ADB) ──────────────────────────────────
Log "Installing scrcpy..."
$scrcpyResult = & winget install --id Genymobile.scrcpy --accept-source-agreements --accept-package-agreements 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "SUCCESS: scrcpy installed"
} else {
    Log "WARNING: scrcpy install exit code $LASTEXITCODE -- $($scrcpyResult -join ' ')"
}

# ── Verify ─────────────────────────────────────────────────────────────────
Log "Verifying installations..."
Start-Sleep -Seconds 5

# Refresh PATH
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")

$adbCheck = & adb --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "ADB verification: $($adbCheck[0])"
} else {
    Log "ADB not yet in PATH (may need reboot)"
}

$scrcpyCheck = & scrcpy --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "scrcpy verification: $($scrcpyCheck[0])"
} else {
    Log "scrcpy not yet in PATH (may need reboot)"
}

$asPath = "C:\Program Files\Android\Android Studio\bin\studio64.exe"
if (Test-Path $asPath) {
    Log "Android Studio binary found: $asPath"
} else {
    Log "Android Studio binary not found at default path (may be elsewhere)"
}

Log "=================================================="
Log "Installation complete. Reboot recommended for PATH update."
Log "=================================================="
