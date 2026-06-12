# deploy-vnet.ps1 — DevOps-User2: Deploy VNet + Subnets
# Run from VS Code terminal or double-click from Explorer.
# Launches Azure login if not already authenticated, then runs Terraform.

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$EnvDir    = Join-Path $ScriptDir "..\environments\user2"

Write-Host ""
Write-Host "============================================"
Write-Host "  DevOps Demo — Deploy VNet + Subnets"
Write-Host "  User: DevOps-User2"
Write-Host "============================================"
Write-Host ""

# ── Step 1: Check Azure CLI ───────────────────────────────────────────────────
if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Error "Azure CLI (az) not found. Please install it from https://aka.ms/installazurecliwindows"
    exit 1
}

# ── Step 2: Check/trigger Azure login ────────────────────────────────────────
Write-Host "Checking Azure authentication..."
$loginCheck = az account show 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "Not logged in — launching Azure login..." -ForegroundColor Yellow
    Write-Host "(A browser window will open for authentication)" -ForegroundColor Cyan
    Write-Host ""
    az login
    if ($LASTEXITCODE -ne 0) { Write-Error "Azure login failed."; exit 1 }
} else {
    $account = $loginCheck | ConvertFrom-Json
    Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green
    Write-Host "  Subscription: $($account.name) ($($account.id))"
}

# ── Step 3: Show subscription and confirm ────────────────────────────────────
Write-Host ""
Write-Host "Active subscription:" -ForegroundColor Cyan
az account show --query "{Name:name, ID:id, Tenant:tenantId}" -o table

Write-Host ""
$confirm = Read-Host "Proceed with this subscription? (y/n)"
if ($confirm -ne "y") {
    Write-Host "Run 'az account set --subscription <id>' to switch, then re-run this script."
    exit 0
}

# ── Step 4: Check Terraform ───────────────────────────────────────────────────
if (-not (Get-Command terraform -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "Terraform not found — installing via winget..." -ForegroundColor Yellow
    winget install HashiCorp.Terraform --silent
}

# ── Step 5: Terraform Init ────────────────────────────────────────────────────
Write-Host ""
Write-Host "── Terraform Init ──────────────────────────────" -ForegroundColor Cyan
Set-Location $EnvDir
terraform init -upgrade

# ── Step 6: Terraform Plan ────────────────────────────────────────────────────
Write-Host ""
Write-Host "── Terraform Plan ──────────────────────────────" -ForegroundColor Cyan
terraform plan -out=tfplan

# ── Step 7: Confirm and Apply ─────────────────────────────────────────────────
Write-Host ""
Write-Host "Review the plan above." -ForegroundColor Yellow
$applyConfirm = Read-Host "Apply this plan and deploy the VNet? (yes/no)"
if ($applyConfirm -eq "yes") {
    Write-Host ""
    Write-Host "── Terraform Apply ─────────────────────────────" -ForegroundColor Cyan
    terraform apply tfplan
    Write-Host ""
    Write-Host "✅ VNet + Subnets deployed!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Outputs:" -ForegroundColor Cyan
    terraform output
} else {
    Write-Host "Deployment cancelled."
}
