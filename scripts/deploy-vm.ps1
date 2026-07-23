# deploy-vm.ps1 - DevOps-User1: Deploy Windows VM
# Run from VS Code terminal or right-click Run with PowerShell
# Launches Azure login if not authenticated, then runs Terraform

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvDir    = Join-Path $ScriptDir "..\environments\user1"

Write-Host ""
Write-Host "============================================"
Write-Host "  DevOps Demo -- Deploy Windows VM"
Write-Host "  User: $env:USERNAME"
Write-Host "============================================"
Write-Host ""

# Check Azure CLI
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI not found. Please install from https://aka.ms/installazurecliwindows"
    exit 1
}

# Clear MSAL token cache FIRST -- prevents DPAPI decryption errors on Cloud PCs
Write-Host "Clearing Azure CLI token cache (Cloud PC DPAPI fix)..." -ForegroundColor DarkGray
$msalFiles = @(
    "$env:USERPROFILE\.azure\msal_token_cache.bin",
    "$env:USERPROFILE\.azure\msal_token_cache.bin.lockfile",
    "$env:USERPROFILE\.azure\accessTokens.json"
)
foreach ($f in $msalFiles) { if (Test-Path $f) { Remove-Item $f -Force } }
$ErrorActionPreference = "Continue"
az logout 2>$null | Out-Null
# Disable DPAPI encryption on token cache -- Cloud PC sessions cannot access DPAPI keys
az config set core.encrypt_token_cache=false 2>$null | Out-Null
$ErrorActionPreference = "Stop"
Write-Host "Cache cleared. Logging in..." -ForegroundColor DarkGray
Write-Host ""

# Azure login -- always fresh in VS Code terminal session
Write-Host "Launching Azure login (browser will open)..." -ForegroundColor Cyan
az login
if ($LASTEXITCODE -ne 0) { Write-Error "Azure login failed."; exit 1 }

$ErrorActionPreference = "Continue"
$loginCheck = az account show 2>$null
$ErrorActionPreference = "Stop"
$account = $loginCheck | ConvertFrom-Json
Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
Write-Host "Subscription: $($account.name) ($($account.id))"

# Show subscription and confirm
Write-Host ""
Write-Host "Active subscription:" -ForegroundColor Cyan
az account show --query "{Name:name, ID:id, Tenant:tenantId}" -o table

Write-Host ""
$confirm = Read-Host "Proceed with this subscription? (y/n)"
if ($confirm -ne "y") {
    Write-Host "Run 'az account set --subscription <id>' to switch, then re-run."
    exit 0
}

# Check Terraform -- refresh PATH first (winget installs may not update current session)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$tf = $null
if (Get-Command terraform -ErrorAction SilentlyContinue) {
    $tf = "terraform"
} else {
    $tfPaths = @(
        "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\Hashicorp.Terraform_Microsoft.Winget.Source_8wekyb3d8bbwe\terraform.exe",
        "$env:ProgramFiles\HashiCorp\Terraform\terraform.exe",
        "C:\ProgramData\chocolatey\bin\terraform.exe"
    )
    foreach ($p in $tfPaths) { if (Test-Path $p) { $tf = $p; break } }
}
if (-not $tf) {
    Write-Host "Terraform not found -- installing via winget..." -ForegroundColor Yellow
    winget install HashiCorp.Terraform --silent --accept-package-agreements --accept-source-agreements
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
    if (Get-Command terraform -ErrorAction SilentlyContinue) {
        $tf = "terraform"
    } else {
        Write-Error "Terraform installed but still not in PATH. Please close and reopen VS Code then retry."
        exit 1
    }
}
Write-Host "Using Terraform: $tf" -ForegroundColor Green

# Terraform Init
Write-Host ""
Write-Host "-- Terraform Init --" -ForegroundColor Cyan
Set-Location $EnvDir
& $tf init -upgrade

# Terraform Plan
Write-Host ""
Write-Host "-- Terraform Plan --" -ForegroundColor Cyan
& $tf plan -out=tfplan

# Confirm and Apply
Write-Host ""
Write-Host "Review the plan above." -ForegroundColor Yellow
$applyConfirm = Read-Host "Apply and deploy the Windows VM? (yes/no)"
if ($applyConfirm -eq "yes") {
    Write-Host ""
    Write-Host "-- Terraform Apply --" -ForegroundColor Cyan
    & $tf apply tfplan
    Write-Host ""
    Write-Host "Windows VM deployed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Outputs:" -ForegroundColor Cyan
    & $tf output
} else {
    Write-Host "Deployment cancelled."
}
