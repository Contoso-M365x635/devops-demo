# logon-sync.ps1
# Deploy via Intune to all Cloud PC users.
# Clones or syncs the devops-demo repo on login,
# then opens VS Code at each user's assigned environment folder.

$repoUrl   = "https://github.com/Contoso-M365x635/devops-demo.git"
$repoPath  = "$env:USERPROFILE\Projects\devops-demo"
$logFile   = "$env:USERPROFILE\Projects\devops-sync.log"
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\Projects" | Out-Null

Add-Content $logFile "$timestamp - Logon sync started for $env:USERNAME"

try {
    if (Test-Path "$repoPath\.git") {
        # Repo already cloned — pull latest changes
        $result = git -C $repoPath pull origin main 2>&1
        Add-Content $logFile "$timestamp - git pull: $result"
    } else {
        # First login — clone the repo
        $result = git clone $repoUrl $repoPath 2>&1
        Add-Content $logFile "$timestamp - git clone: $result"
    }
} catch {
    Add-Content $logFile "$timestamp - ERROR: $_"
}

# Open VS Code at the correct environment folder based on username
switch ($env:USERNAME.ToLower()) {
    "devops-user1" {
        $folder = "$repoPath\environments\user1"
        Add-Content $logFile "$timestamp - Opening VS Code for User1 (Windows VM)"
    }
    "devops-user2" {
        $folder = "$repoPath\environments\user2"
        Add-Content $logFile "$timestamp - Opening VS Code for User2 (VNet)"
    }
    default {
        $folder = $repoPath
        Add-Content $logFile "$timestamp - Opening VS Code at repo root (unmatched user: $env:USERNAME)"
    }
}

if (Get-Command "code" -ErrorAction SilentlyContinue) {
    Start-Process "code" -ArgumentList $folder
} else {
    # Fallback to full path if code not in PATH yet
    $codePath = "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd"
    if (Test-Path $codePath) {
        Start-Process $codePath -ArgumentList $folder
    }
}

Add-Content $logFile "$timestamp - Logon sync complete"
