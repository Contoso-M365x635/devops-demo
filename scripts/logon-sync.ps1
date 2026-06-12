# logon-sync.ps1
# ─────────────────────────────────────────────────────────────────────────────
# PURPOSE : On Cloud PC login — clone or sync the devops-demo repo, then open
#           VS Code at each user's assigned environment folder.
#
# DEPLOY  : Intune → Devices → Scripts → Add PowerShell script
#           - Run as logged-on user : Yes
#           - Run in 64-bit PowerShell : Yes
#           - Enforce signature check  : No
# ─────────────────────────────────────────────────────────────────────────────

$repoUrl   = "https://github.com/Contoso-M365x635/devops-demo.git"
$repoPath  = "$env:USERPROFILE\Projects\devops-demo"
$logFile   = "$env:USERPROFILE\Projects\devops-sync.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# Ensure Projects folder exists
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Projects" | Out-Null

function Log($msg) {
    $entry = "$timestamp - $msg"
    Add-Content $logFile $entry
    Write-Host $entry
}

Log "──────────────────────────────────────────"
Log "Logon sync started for user: $env:USERNAME"

# ── Clone or Pull ─────────────────────────────────────────────────────────────
if (Test-Path "$repoPath\.git") {
    Log "Repo exists — pulling latest changes..."
    $result = git -C $repoPath pull origin main 2>&1
    Log "git pull: $result"
} else {
    Log "First login — cloning repo..."
    $result = git clone $repoUrl $repoPath 2>&1
    Log "git clone: $result"
}

# ── Resolve VS Code path ──────────────────────────────────────────────────────
$code = $null
if (Get-Command "code" -ErrorAction SilentlyContinue) {
    $code = "code"
} elseif (Test-Path "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd") {
    $code = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
} else {
    Log "WARNING: VS Code not found in PATH or default install location"
}

# ── Open VS Code at the right folder based on username ───────────────────────
# UPDATE THESE to match your actual Entra ID usernames
switch ($env:USERNAME.ToLower()) {

    "devops-user1" {
        $folder = "$repoPath\environments\user1"
        Log "Opening VS Code for User1 → environments/user1 (Windows VM)"
        if ($code) { Start-Process $code -ArgumentList $folder }
    }

    "devops-user2" {
        $folder = "$repoPath\environments\user2"
        Log "Opening VS Code for User2 → environments/user2 (VNet)"
        if ($code) { Start-Process $code -ArgumentList $folder }
    }

    default {
        # Fallback — open repo root for any other user
        Log "Unknown user '$env:USERNAME' — opening VS Code at repo root"
        if ($code) { Start-Process $code -ArgumentList $repoPath }
    }
}

Log "Logon sync complete ✓"
Log "──────────────────────────────────────────"
