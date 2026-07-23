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

# Check/trigger Azure login
Write-Host "Checking Azure authentication..."
$ErrorActionPreference = "Continue"
$loginCheck = az account show 2>$null
$azLoggedIn = $LASTEXITCODE
$ErrorActionPreference = "Stop"
if ($azLoggedIn -ne 0) {
    Write-Host ""
    Write-Host "Not logged in -- launching Azure login..." -ForegroundColor Yellow
    Write-Host "(A browser window will open)" -ForegroundColor Cyan
    Write-Host ""
    az login
    if ($LASTEXITCODE -ne 0) { Write-Error "Azure login failed."; exit 1 }
} else {
    $account = $loginCheck | ConvertFrom-Json
    Write-Host "Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "Subscription: $($account.name) ($($account.id))"
}

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

# Check Terraform
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host "Terraform not found -- installing via winget..." -ForegroundColor Yellow
    winget install HashiCorp.Terraform --silent --accept-package-agreements --accept-source-agreements
}

# Terraform Init
Write-Host ""
Write-Host "-- Terraform Init --" -ForegroundColor Cyan
Set-Location $EnvDir
terraform init -upgrade

# Terraform Plan
Write-Host ""
Write-Host "-- Terraform Plan --" -ForegroundColor Cyan
terraform plan -out=tfplan

# Confirm and Apply
Write-Host ""
Write-Host "Review the plan above." -ForegroundColor Yellow
$applyConfirm = Read-Host "Apply and deploy the Windows VM? (yes/no)"
if ($applyConfirm -eq "yes") {
    Write-Host ""
    Write-Host "-- Terraform Apply --" -ForegroundColor Cyan
    terraform apply tfplan
    Write-Host ""
    Write-Host "Windows VM deployed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Outputs:" -ForegroundColor Cyan
    terraform output
} else {
    Write-Host "Deployment cancelled."
}
