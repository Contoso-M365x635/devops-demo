# install-devops-tools.ps1
# Install Git and Terraform via winget for DevOps Cloud PCs
# Deploy via Intune as SYSTEM (no user context needed)

$logFile = "C:\ProgramData\Intune\install-devops-tools.log"

function Log($msg) {
    $entry = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') - $msg"
    Add-Content -Path $logFile -Value $entry
}

Log "=================================================="
Log "Installing DevOps tools: Git and Terraform"
Log "=================================================="

# Check if winget is available
$winget = Get-Command winget -ErrorAction SilentlyContinue
if (-not $winget) {
    Log "ERROR: winget not found. Cannot proceed."
    exit 1
}

Log "winget found at: $(& winget --version)"

# Install Git
Log "Installing Git..."
$gitInstall = & winget install --id Git.Git --accept-source-agreements --accept-package-agreements 2>&1
$gitExitCode = $LASTEXITCODE
if ($gitExitCode -eq 0) {
    Log "SUCCESS: Git installed"
} else {
    Log "WARNING: Git install returned exit code $gitExitCode"
    Log "Output: $($gitInstall -join ' ')"
}

# Install Terraform
Log "Installing Terraform..."
$tfInstall = & winget install --id HashiCorp.Terraform --accept-source-agreements --accept-package-agreements 2>&1
$tfExitCode = $LASTEXITCODE
if ($tfExitCode -eq 0) {
    Log "SUCCESS: Terraform installed"
} else {
    Log "WARNING: Terraform install returned exit code $tfExitCode"
    Log "Output: $($tfInstall -join ' ')"
}

# Verify installations
Log "Verifying installations..."
Start-Sleep -Seconds 3

$gitCheck = & git --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "Git verification: $gitCheck"
} else {
    Log "Git verification failed (may need PATH refresh)"
}

$tfCheck = & terraform --version 2>&1
if ($LASTEXITCODE -eq 0) {
    Log "Terraform verification: $($tfCheck[0])"
} else {
    Log "Terraform verification failed (may need PATH refresh)"
}

Log "=================================================="
Log "Installation complete. User may need to log out/in for PATH to update."
Log "=================================================="
