<#
.SYNOPSIS
    Automated deployment and validation script for Vite + React projects on Vercel.
.DESCRIPTION
    This script validates the build environment, ensures dependencies are installed,
    builds the application, checks for required environment variables, maps them
    to Vercel production settings, deploys the project, and provides a rollback utility.
.PARAMETER Rollback
    Rolls back the production deployment to the previous version.
#>

[CmdletBinding()]
param (
    [switch]$Rollback
)

Clear-Host
Write-Host "=========================================" -ForegroundColor Cyan
Write-Host "     Vercel Deployment Automation        " -ForegroundColor Cyan
Write-Host "=========================================" -ForegroundColor Cyan

# Define required environment variables
$RequiredEnvs = @(
    "VITE_CLERK_PUBLISHABLE_KEY",
    "VITE_SUPABASE_URL",
    "VITE_SUPABASE_ANON_KEY"
)

# Rollback Logic
if ($Rollback) {
    Write-Host "[*] Starting rollback sequence..." -ForegroundColor Yellow
    
    # Check if vercel CLI is available
    if (!(Get-Command vercel -ErrorAction SilentlyContinue)) {
        Write-Host "[!] Vercel CLI is not installed or not in the PATH." -ForegroundColor Red
        Write-Host "    Install it globally using: npm install -g vercel" -ForegroundColor Yellow
        exit 1
    }

    Write-Host "[*] Fetching recent production deployments..." -ForegroundColor Cyan
    vercel list --prod

    Write-Host ""
    Write-Host "[?] To roll back, run the following Vercel command:" -ForegroundColor Cyan
    Write-Host "    vercel rollback <deployment-id-or-url>" -ForegroundColor Green
    Write-Host ""
    Write-Host "Alternatively, running 'vercel rollback' without arguments will prompt you to select a deployment." -ForegroundColor Yellow
    
    $confirm = Read-Host "Would you like to run interactive rollback now? (y/n)"
    if ($confirm -eq 'y' -or $confirm -eq 'yes') {
        vercel rollback
    } else {
        Write-Host "Rollback cancelled." -ForegroundColor Gray
    }
    exit 0
}

# 1. Validation of Build Environment & CLI Tools
Write-Host "[1/5] Checking environment requirements..." -ForegroundColor Cyan

if (!(Get-Command node -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Node.js is not installed. Please download it from https://nodejs.org/" -ForegroundColor Red
    exit 1
}

if (!(Get-Command vercel -ErrorAction SilentlyContinue)) {
    Write-Host "[!] Vercel CLI is not installed. Installing it locally in devDependencies..." -ForegroundColor Yellow
    # Check if npm is installed
    if (!(Get-Command npm -ErrorAction SilentlyContinue)) {
        Write-Host "[!] npm is not found. Cannot proceed." -ForegroundColor Red
        exit 1
    }
    Write-Host "[*] Installing vercel CLI..." -ForegroundColor Gray
    npm install --save-dev vercel
}

# 2. Check Git working directory status
Write-Host "[2/5] Checking git status..." -ForegroundColor Cyan
if (Get-Command git -ErrorAction SilentlyContinue) {
    $gitStatus = git status --porcelain
    if ($gitStatus) {
        Write-Host "[!] WARNING: You have uncommitted changes in your working tree:" -ForegroundColor Yellow
        Write-Host $gitStatus -ForegroundColor Gray
        $choice = Read-Host "Do you want to proceed with deployment anyway? (y/n)"
        if ($choice -ne 'y' -and $choice -ne 'yes') {
            Write-Host "[-] Deployment cancelled by user to commit changes." -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "[+] Git working tree is clean. Ready to deploy latest commit." -ForegroundColor Green
    }
} else {
    Write-Host "[!] Git not found. Skipping repository status check." -ForegroundColor Yellow
}

# 3. Environment Variable Mapping (Local to Production)
Write-Host "[3/5] Resolving and mapping environment variables..." -ForegroundColor Cyan
$LocalEnvs = @{}

# Try to find and load .env or .env.local
$envFiles = @(".env.local", ".env")

foreach ($file in $envFiles) {
    if (Test-Path $file) {
        Write-Host "[+] Found environment file: $file" -ForegroundColor Green
        Get-Content $file | Where-Object { $_ -match "^[^#\s]+" } | ForEach-Object {
            $parts = $_ -split '=', 2
            if ($parts.Length -eq 2) {
                $key = $parts[0].Trim()
                $val = $parts[1].Trim().Trim('"').Trim("'")
                $LocalEnvs[$key] = $val
            }
        }
        break
    }
}

# Check for missing variables
$missingEnvs = @()
foreach ($envVar in $RequiredEnvs) {
    if (!$LocalEnvs.ContainsKey($envVar) -and [string]::IsNullOrEmpty([Environment]::GetEnvironmentVariable($envVar))) {
        $missingEnvs += $envVar
    }
}

if ($missingEnvs.Count -gt 0) {
    Write-Host "[!] Missing required local environment variables: $($missingEnvs -join ', ')" -ForegroundColor Yellow
    Write-Host "Please provide their values to set up Vercel environment mapping:" -ForegroundColor Cyan
    foreach ($envVar in $missingEnvs) {
        $val = Read-Host "Enter value for $envVar"
        if (![string]::IsNullOrEmpty($val)) {
            $LocalEnvs[$envVar] = $val
            # Optionally write back to a .env file
            Add-Content -Path ".env" -Value "$envVar=$val"
            Write-Host "[+] Saved $envVar to .env" -ForegroundColor Gray
        } else {
            Write-Host "[!] $envVar cannot be empty. Aborting." -ForegroundColor Red
            exit 1
        }
    }
}

# Sync environment variables to Vercel
Write-Host "[*] Checking Vercel login & project status..." -ForegroundColor Gray
& npx vercel whoami *>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Not logged into Vercel. Redirecting to login..." -ForegroundColor Yellow
    & npx vercel login
}

# Link project if not already linked
if (!(Test-Path ".vercel")) {
    Write-Host "[!] Project is not linked to Vercel. Linking now..." -ForegroundColor Yellow
    & npx vercel link
}

# Map/add environment variables on Vercel
Write-Host "[*] Mapping environment variables to Vercel Production..." -ForegroundColor Gray
foreach ($envVar in $RequiredEnvs) {
    $val = $LocalEnvs[$envVar]
    if ([string]::IsNullOrEmpty($val)) {
        $val = [Environment]::GetEnvironmentVariable($envVar)
    }
    
    Write-Host "[*] Syncing $envVar to Vercel..." -ForegroundColor Gray
    # Try adding environment variable, redirecting errors in case it already exists
    # Vercel env add requires: Name, Environment (production, preview, development), and Value
    # Using pipeline to send value to vercel env add command to avoid interactive prompts
    $val | & npx vercel env add $envVar production 2>$null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "[+] Successfully set $envVar on Vercel production." -ForegroundColor Green
    } else {
        Write-Host "[~] $envVar might already be configured on Vercel (or update skipped)." -ForegroundColor Yellow
    }
}

# 4. Validate Current Build in the Antigravity Environment
Write-Host "[4/5] Running local validation & build..." -ForegroundColor Cyan

# Install dependencies if node_modules doesn't exist
if (!(Test-Path "node_modules")) {
    Write-Host "[*] Installing dependencies..." -ForegroundColor Gray
    npm install
}

# Run build
Write-Host "[*] Compiling application (npm run build)..." -ForegroundColor Gray
$buildOutput = npm run build 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Build failed! Please fix compiler errors before deploying." -ForegroundColor Red
    Write-Host $buildOutput -ForegroundColor DarkRed
    exit 1
}
Write-Host "[+] Build validated successfully!" -ForegroundColor Green

# Run linting
Write-Host "[*] Linting codebase (npm run lint)..." -ForegroundColor Gray
$lintOutput = npm run lint 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Lint checks failed! Proceed with caution." -ForegroundColor Yellow
    Write-Host $lintOutput -ForegroundColor DarkYellow
    $choice = Read-Host "Proceed with deployment despite lint failures? (y/n)"
    if ($choice -ne 'y' -and $choice -ne 'yes') {
        Write-Host "[-] Deployment aborted due to lint failures." -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "[+] Lint checks passed successfully!" -ForegroundColor Green
}

# 5. Execute Vercel Production Deployment
Write-Host "[5/5] Deploying latest commit to Vercel Production..." -ForegroundColor Cyan
& npx vercel --prod --yes
if ($LASTEXITCODE -eq 0) {
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "   Deployment Completed Successfully!    " -ForegroundColor Green
    Write-Host "=========================================" -ForegroundColor Green
    Write-Host "[+] Production URL: Check Vercel Dashboard or output above." -ForegroundColor Green
} else {
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "          Deployment Failed!             " -ForegroundColor Red
    Write-Host "=========================================" -ForegroundColor Red
    Write-Host "[!] Vercel deployment command exited with errors." -ForegroundColor Red
    Write-Host "[?] To roll back or manage previous builds, run:" -ForegroundColor Yellow
    Write-Host "    .\deploy.ps1 -Rollback" -ForegroundColor Yellow
}
