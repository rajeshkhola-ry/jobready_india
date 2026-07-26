# ==========================================
# GetReadyJob Compression Server Deployment Script
# ==========================================
# This script deploys the compression server and verifies everything is working
# Run this from: c:\JobReadyIndia\jobready_india\lib\
# ==========================================

Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "GetReadyJob Compression Server Deployment" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host ""

# Color functions
function Write-Success {
    param([string]$Message)
    Write-Host "✅ $Message" -ForegroundColor Green
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ️  $Message" -ForegroundColor Blue
}

function Write-Warning {
    param([string]$Message)
    Write-Host "⚠️  $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "❌ $Message" -ForegroundColor Red
}

# ==========================================
# STEP 1: VERIFY PREREQUISITES
# ==========================================
Write-Host ""
Write-Host "STEP 1: Verifying Prerequisites..." -ForegroundColor Cyan

# Check Node.js
$nodeVersion = node --version 2>$null
if ($nodeVersion) {
    Write-Success "Node.js found: $nodeVersion"
} else {
    Write-Error "Node.js not found. Please install Node.js 16+ from https://nodejs.org"
    exit 1
}

# Check Docker (optional)
$dockerVersion = docker --version 2>$null
if ($dockerVersion) {
    Write-Success "Docker found: $dockerVersion"
    $useDocker = Read-Host "Use Docker for deployment? (y/n)"
    if ($useDocker -eq "y") { $useDocker = $true } else { $useDocker = $false }
} else {
    Write-Warning "Docker not found (optional). Will use direct Node.js deployment."
    $useDocker = $false
}

# ==========================================
# STEP 2: VERIFY FILES
# ==========================================
Write-Host ""
Write-Host "STEP 2: Verifying Deployment Files..." -ForegroundColor Cyan

$files = @(
    "compression_server.js",
    "package.json",
    "Dockerfile",
    "docker-compose.yml",
    "public/index.html",
    "public/design-system.css"
)

$allFilesExist = $true
foreach ($file in $files) {
    if (Test-Path $file) {
        Write-Success "$file"
    } else {
        Write-Error "$file - MISSING!"
        $allFilesExist = $false
    }
}

if (-not $allFilesExist) {
    Write-Error "Some required files are missing. Please check your project structure."
    exit 1
}

# ==========================================
# STEP 3: INSTALL DEPENDENCIES
# ==========================================
Write-Host ""
Write-Host "STEP 3: Installing Dependencies..." -ForegroundColor Cyan

if (-not (Test-Path "node_modules")) {
    Write-Info "Running: npm install"
    npm install
    if ($LASTEXITCODE -ne 0) {
        Write-Error "npm install failed"
        exit 1
    }
    Write-Success "Dependencies installed"
} else {
    Write-Info "node_modules already exists, skipping npm install"
    $reinstall = Read-Host "Reinstall dependencies? (y/n)"
    if ($reinstall -eq "y") {
        npm install
    }
}

# ==========================================
# STEP 4: DEPLOY
# ==========================================
Write-Host ""
Write-Host "STEP 4: Starting Compression Server..." -ForegroundColor Cyan

if ($useDocker) {
    Write-Info "Building Docker image..."
    docker build -t getreadyjob-compression:latest .
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Docker build failed"
        exit 1
    }

    Write-Info "Starting docker-compose..."
    docker-compose up -d
    if ($LASTEXITCODE -ne 0) {
        Write-Error "docker-compose up failed"
        exit 1
    }

    Write-Success "Docker containers starting..."
    Start-Sleep -Seconds 3

    Write-Info "Checking container status..."
    docker-compose ps

    Write-Success "Server starting on: http://localhost:3000"
} else {
    Write-Info "Starting Node.js server..."
    Write-Warning "Keep this terminal open. The server will run in the foreground."
    Write-Warning "To stop: Press Ctrl+C"
    Write-Info "Server will be available at: http://localhost:3000"

    Read-Host "Press Enter to continue and start the server"

    npm start
}

# ==========================================
# STEP 5: VERIFY DEPLOYMENT
# ==========================================
if ($useDocker) {
    Write-Host ""
    Write-Host "STEP 5: Verifying Deployment..." -ForegroundColor Cyan
    Write-Info "Waiting 5 seconds for server to be ready..."
    Start-Sleep -Seconds 5

    try {
        $response = Invoke-WebRequest -Uri "http://localhost:3000/api/info" -UseBasicParsing -ErrorAction Stop
        if ($response.StatusCode -eq 200) {
            Write-Success "Server is responding!"
            Write-Success "API endpoint working!"

            # Parse JSON response
            $info = $response.Content | ConvertFrom-Json
            Write-Success "Max file size: $($info.maxFileSize)"
            Write-Success "Quality range: $($info.qualityRange.min)-$($info.qualityRange.max)%"
        }
    } catch {
        Write-Warning "Could not verify server. It may still be starting."
        Write-Info "Try opening: http://localhost:3000 in your browser in a few seconds"
    }
}

Write-Host ""
Write-Host "===========================================" -ForegroundColor Green
Write-Host "✅ DEPLOYMENT COMPLETE" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next Steps:" -ForegroundColor Cyan
Write-Host "1. Open http://localhost:3000 in your browser" -ForegroundColor White
Write-Host "2. Test compression with sample files" -ForegroundColor White
Write-Host "3. Check mobile responsiveness" -ForegroundColor White
Write-Host "4. Configure domain/reverse proxy for production" -ForegroundColor White
Write-Host "5. Read LAUNCH_GUIDE.md for production setup" -ForegroundColor White
Write-Host ""

if ($useDocker) {
    Write-Host "Useful Docker Commands:" -ForegroundColor Cyan
    Write-Host "docker-compose ps              # View running containers" -ForegroundColor White
    Write-Host "docker-compose logs -f         # View server logs" -ForegroundColor White
    Write-Host "docker-compose stop            # Stop containers" -ForegroundColor White
    Write-Host "docker-compose down            # Stop and remove containers" -ForegroundColor White
}

Write-Host ""
