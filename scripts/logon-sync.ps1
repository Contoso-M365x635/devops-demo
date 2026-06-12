# logon-sync.ps1
# ─────────────────────────────────────────────────────────────────────────────
# PURPOSE : On Cloud PC login — clone or sync the public devops-demo repo,
#           then open VS Code at the folder mapped to the current user.
#           No GitHub credentials required — repo is public.
#
# DEPLOY  : Intune → Devices → Scripts → Add PowerShell script
#           - Run as logged-on user    : Yes
#           - Run in 64-bit PowerShell : Yes
#           - Enforce signature check  : No
# ─────────────────────────────────────────────────────────────────────────────

$repoUrl  = "https://github.com/Contoso-M365x635/devops-demo.git"
$repoPath = "$env:USERPROFILE\Projects\devops-demo"
$logFile  = "$env:USERPROFILE\Projects\devops-sync.log"

New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Projects" | Out-Null

function Log($msg) {
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content $logFile $entry
    Write-Host $entry
}

Log "══════════════════════════════════════════"
Log "Logon sync started"

# ── Auto-detect current user (script runs in user context) ────────────────────
$username = $env:USERNAME
$upn      = (whoami /upn 2>$null)
Log "User    : $username"
Log "UPN     : $upn"
Log "Machine : $env:COMPUTERNAME"

# ── Clone or Pull (no auth needed — public repo) ──────────────────────────────
if (Test-Path "$repoPath\.git") {
    Log "Repo exists — pulling latest..."
    $result = git -C $repoPath pull origin main 2>&1
    Log "git pull: $result"
} else {
    Log "First login — cloning repo..."
    $result = git clone $repoUrl $repoPath 2>&1
    Log "git clone: $result"
}

# ── Read user → folder mapping from repo config ───────────────────────────────
$configFile = "$repoPath\config\user-map.json"
$folder     = $repoPath   # fallback: open repo root

if (Test-Path $configFile) {
    $config    = Get-Content $configFile -Raw | ConvertFrom-Json
    $upnPrefix = ($upn -split "@")[0]

    # Try: exact username → UPN prefix → full UPN → default
    $match = $config.users.$username `
          ?? $config.users.$upnPrefix `
          ?? $config.users.$upn

    if ($match) {
        $folder = Join-Path $repoPath ($match.Replace("/", "\"))
        Log "Mapped '$username' → $match"
    } elseif ($config.default) {
        $folder = Join-Path $repoPath ($config.default.Replace("/", "\"))
        Log "Using default mapping → $($config.default)"
    } else {
        Log "No mapping for '$username' — opening repo root"
    }
} else {
    Log "WARNING: config/user-map.json not found — opening repo root"
}

# ── Resolve VS Code ───────────────────────────────────────────────────────────
$code = $null
if     (Get-Command "code" -ErrorAction SilentlyContinue)                              { $code = "code" }
elseif (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd")         { $code = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" }

# ── Launch VS Code ────────────────────────────────────────────────────────────
if ($code) {
    Log "Opening VS Code at: $folder"
    Start-Process $code -ArgumentList $folder
} else {
    Log "WARNING: VS Code not found — skipping launch"
}

Log "Logon sync complete ✓"
Log "══════════════════════════════════════════"
