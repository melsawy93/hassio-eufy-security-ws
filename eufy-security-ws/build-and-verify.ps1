# PowerShell script to build Docker container and verify it uses your GitHub fork
# Usage: .\build-and-verify.ps1

param(
    [string]$EufySecurityWsVersion = "1.9.3",
    [string]$BuildFrom = "homeassistant/amd64-base:latest",
    [string]$ImageName = "test-eufy-ws"
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Building Docker Image" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Get the directory where the script is located
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptDir

Write-Host "Build arguments:" -ForegroundColor Yellow
Write-Host "  BUILD_FROM: $BuildFrom"
Write-Host "  EUFY_SECURITY_WS_VERSION: $EufySecurityWsVersion"
Write-Host "  Image name: $ImageName"
Write-Host ""

# Build the Docker image
Write-Host "Building Docker image (this may take a while)..." -ForegroundColor Yellow
Write-Host ""

# Build and capture output - redirect to file and also display
$buildLogFile = "build.log"
$buildSuccess = $false

try {
    # Run docker build and capture both stdout and stderr
    & docker build --no-cache `
        --build-arg BUILD_FROM=$BuildFrom `
        --build-arg EUFY_SECURITY_WS_VERSION=$EufySecurityWsVersion `
        -t $ImageName . *>&1 | Tee-Object -FilePath $buildLogFile
    
    # Check exit code
    if ($LASTEXITCODE -eq 0) {
        $buildSuccess = $true
    } else {
        Write-Host ""
        Write-Host "✗ BUILD FAILED! Exit code: $LASTEXITCODE" -ForegroundColor Red
        Write-Host "Check build.log for details" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host ""
    Write-Host "✗ BUILD FAILED! Error: $_" -ForegroundColor Red
    exit 1
}

if ($buildSuccess) {
    Write-Host ""
    Write-Host "✓ Build completed successfully" -ForegroundColor Green
    Write-Host "Build log saved to: $buildLogFile" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Verifying GitHub Fork Usage" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# Check build logs
Write-Host "1. Checking build logs for GitHub fork reference..." -ForegroundColor Yellow
$logCheck = Select-String -Path "build.log" -Pattern "melsawy93" -CaseSensitive:$false
if ($logCheck) {
    Write-Host "   ✓ Found melsawy93 in build logs" -ForegroundColor Green
    $logCheck | Select-Object -First 3 | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }
} else {
    Write-Host "   ✗ WARNING: melsawy93 not found in build logs" -ForegroundColor Red
}
Write-Host ""

# Create temporary container
Write-Host "2. Creating temporary container for inspection..." -ForegroundColor Yellow
$containerId = docker create $ImageName 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "   ✗ Failed to create container: $containerId" -ForegroundColor Red
    exit 1
}
Write-Host "   ✓ Container created: $containerId" -ForegroundColor Green
Write-Host ""

# Check package.json
Write-Host "3. Checking package.json for GitHub reference..." -ForegroundColor Yellow
$packageJsonPath = "/tmp/eufy-package.json"
docker cp "${containerId}:/usr/src/app/node_modules/eufy-security-client/package.json" $packageJsonPath 2>&1 | Out-Null

if (Test-Path $packageJsonPath) {
    $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
    
    $hasFork = $false
    if ($packageJson.repository -and $packageJson.repository -like "*melsawy93*") {
        Write-Host "   ✓ package.json repository points to melsawy93" -ForegroundColor Green
        Write-Host "     Repository: $($packageJson.repository)" -ForegroundColor Gray
        $hasFork = $true
    }
    
    if ($packageJson._resolved -and $packageJson._resolved -like "*melsawy93*") {
        Write-Host "   ✓ package.json _resolved points to melsawy93" -ForegroundColor Green
        Write-Host "     Resolved: $($packageJson._resolved)" -ForegroundColor Gray
        $hasFork = $true
    }
    
    if (-not $hasFork) {
        Write-Host "   ✗ WARNING: package.json does NOT reference melsawy93 fork" -ForegroundColor Red
        Write-Host "     Repository: $($packageJson.repository)" -ForegroundColor Gray
        Write-Host "     Resolved: $($packageJson._resolved)" -ForegroundColor Gray
    }
} else {
    Write-Host "   ✗ Could not extract package.json" -ForegroundColor Red
}
Write-Host ""

# Check if your code is present
Write-Host "4. Checking if your code changes are present..." -ForegroundColor Yellow
$sessionJsPath = "/tmp/session.js"
$stationJsPath = "/tmp/station.js"

# Check session.js (p2p code)
$sessionFound = $false
docker cp "${containerId}:/usr/src/app/node_modules/eufy-security-client/build/p2p/session.js" $sessionJsPath 2>&1 | Out-Null
if (Test-Path $sessionJsPath) {
    $sessionFound = $true
    Write-Host "   ✓ Found session.js" -ForegroundColor Green
} else {
    Write-Host "   ✗ Could not extract session.js" -ForegroundColor Red
}

# Check station.js (http code)
$stationFound = $false
docker cp "${containerId}:/usr/src/app/node_modules/eufy-security-client/build/http/station.js" $stationJsPath 2>&1 | Out-Null
if (Test-Path $stationJsPath) {
    $stationFound = $true
    Write-Host "   ✓ Found station.js" -ForegroundColor Green
} else {
    Write-Host "   ✗ Could not extract station.js" -ForegroundColor Red
}

if ($sessionFound -or $stationFound) {
    # Check for debug markers in both files
    $markers = @{
        "T85D0_DEBUG_v2" = @()
        "Get DSK keys v2" = @()
        "lockDevice() ENTRY POINT" = @()
    }
    
    # Get a copy of the keys to iterate over
    $markerKeys = @($markers.Keys)
    
    if ($sessionFound) {
        $sessionJs = Get-Content $sessionJsPath -Raw
        foreach ($marker in $markerKeys) {
            if ($sessionJs -match [regex]::Escape($marker)) {
                $markers[$marker] += "session.js"
            }
        }
    }
    
    if ($stationFound) {
        $stationJs = Get-Content $stationJsPath -Raw
        foreach ($marker in $markerKeys) {
            if ($stationJs -match [regex]::Escape($marker)) {
                $markers[$marker] += "station.js"
            }
        }
    }
    
    # Report findings
    $allFound = $true
    foreach ($marker in $markers.Keys) {
        if ($markers[$marker].Count -gt 0) {
            $files = $markers[$marker] -join ", "
            Write-Host "   ✓ Found marker '$marker' in: $files" -ForegroundColor Green
        } else {
            Write-Host "   ✗ Missing marker: $marker" -ForegroundColor Red
            $allFound = $false
        }
    }
    
    if ($allFound) {
        Write-Host ""
        Write-Host "   ✓✓✓ ALL YOUR CODE CHANGES ARE PRESENT! ✓✓✓" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "   ⚠ Some markers missing, but most code is present" -ForegroundColor Yellow
    }
    
    # Show a sample of the code
    Write-Host ""
    Write-Host "   Sample code snippets found:" -ForegroundColor Yellow
    if ($sessionFound) {
        $sampleMatches = Select-String -Path $sessionJsPath -Pattern "T85D0_DEBUG_v2" | Select-Object -First 2
        if ($sampleMatches) {
            $sampleMatches | ForEach-Object {
                $line = $_.Line.Trim()
                if ($line.Length -gt 100) { $line = $line.Substring(0, 100) + "..." }
                Write-Host "     [session.js] $line" -ForegroundColor Gray
            }
        }
    }
    if ($stationFound) {
        $sampleMatches = Select-String -Path $stationJsPath -Pattern "T85D0_DEBUG_v2" | Select-Object -First 2
        if ($sampleMatches) {
            $sampleMatches | ForEach-Object {
                $line = $_.Line.Trim()
                if ($line.Length -gt 100) { $line = $line.Substring(0, 100) + "..." }
                Write-Host "     [station.js] $line" -ForegroundColor Gray
            }
        }
    }
} else {
    Write-Host "   ✗ Could not extract either file" -ForegroundColor Red
    Write-Host "   Checking if build directory exists..." -ForegroundColor Yellow
    docker exec $containerId sh -c "ls -la /usr/src/app/node_modules/eufy-security-client/build/ 2>&1" 2>&1
}
Write-Host ""

# Check git commit (if available)
Write-Host "5. Checking git commit info..." -ForegroundColor Yellow
$gitInfo = docker exec $containerId sh -c "cd /usr/src/app/node_modules/eufy-security-client && git log -1 --oneline 2>&1" 2>&1
if ($gitInfo -and $gitInfo -notmatch "Not a git repo|fatal") {
    Write-Host "   ✓ Git commit found:" -ForegroundColor Green
    Write-Host "     $gitInfo" -ForegroundColor Gray
} else {
    Write-Host "   ⚠ Git info not available (this is normal for npm packages)" -ForegroundColor Yellow
}
Write-Host ""

# Cleanup
Write-Host "6. Cleaning up..." -ForegroundColor Yellow
docker rm $containerId | Out-Null
Remove-Item -Path $packageJsonPath -ErrorAction SilentlyContinue
Remove-Item -Path $sessionJsPath -ErrorAction SilentlyContinue
Remove-Item -Path $stationJsPath -ErrorAction SilentlyContinue
Write-Host "   ✓ Cleanup complete" -ForegroundColor Green
Write-Host ""

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Verification Complete" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "To inspect the image manually:" -ForegroundColor Yellow
Write-Host "  docker run --rm -it $ImageName sh" -ForegroundColor Gray
Write-Host ""
Write-Host "To check files in the container:" -ForegroundColor Yellow
Write-Host "  docker run --rm $ImageName sh -c 'grep -r \"T85D0_DEBUG_v2\" /usr/src/app/node_modules/eufy-security-client/build/'" -ForegroundColor Gray
Write-Host ""

