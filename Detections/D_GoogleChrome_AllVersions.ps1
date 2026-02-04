### BGU
### 08.09.2025
### Detect Google Chrome on target devices

<# 
.SYNOPSIS 
Detect Google Chrome on target devices 
.DESCRIPTION 
Below script will detect if Google Chrome is installed with minimum required version or higher.
.NOTES      
.LINK 
#>

# Define the paths where Chrome might be installed
$paths = @(
    "$env:ProgramFiles\Google\Chrome\Application\chrome.exe",
    "$env:ProgramFiles(x86)\Google\Chrome\Application\chrome.exe",
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
)

# Define the minimum required version
$minimumVersion = [version]"YOUR VERSION HERE"  # Replace YOUR VERSION HERE with the required version
$detected = $false
$installedVersion = $null

# Check each path for Chrome installation
foreach ($path in $paths) {
    if (Test-Path $path) {
        try {
            $versionInfo = (Get-Item $path).VersionInfo.ProductVersion
            # Chrome version format can be like "YOUR VERSION HERE" - convert to version object
            $installedVersion = [version]$versionInfo
            
            # Check if installed version meets minimum requirement
            if ($installedVersion -ge $minimumVersion) {
                $detected = $true
                Write-Output "Google Chrome $installedVersion detected (meets minimum requirement $minimumVersion)"
                break
            } else {
                Write-Output "Google Chrome $installedVersion found but below minimum requirement $minimumVersion"
            }
        }
        catch {
            Write-Output "Google Chrome found at $path but version could not be determined"
        }
    }
}

# Alternative: Check registry for Chrome installation
if (-not $detected) {
    try {
        # Check 64-bit registry
        $regPath = "HKLM:\SOFTWARE\Google\Chrome"
        if (Test-Path $regPath) {
            $versionProperty = Get-ItemProperty -Path $regPath -Name "Version" -ErrorAction SilentlyContinue
            if ($versionProperty -and $versionProperty.Version) {
                $regVersion = [version]$versionProperty.Version
                if ($regVersion -ge $minimumVersion) {
                    $detected = $true
                    $installedVersion = $regVersion
                    Write-Output "Google Chrome $regVersion detected via registry (meets minimum requirement $minimumVersion)"
                }
            }
        }
        
        # Check 32-bit registry on 64-bit systems
        if (-not $detected) {
            $regPath32 = "HKLM:\SOFTWARE\WOW6432Node\Google\Chrome"
            if (Test-Path $regPath32) {
                $versionProperty = Get-ItemProperty -Path $regPath32 -Name "Version" -ErrorAction SilentlyContinue
                if ($versionProperty -and $versionProperty.Version) {
                    $regVersion = [version]$versionProperty.Version
                    if ($regVersion -ge $minimumVersion) {
                        $detected = $true
                        $installedVersion = $regVersion
                        Write-Output "Google Chrome $regVersion detected via registry (meets minimum requirement $minimumVersion)"
                    }
                }
            }
        }
        
        # Additional check: Chrome uninstall registry entries
        if (-not $detected) {
            $uninstallPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
            )
            
            foreach ($uninstallPath in $uninstallPaths) {
                $chromeEntries = Get-ItemProperty $uninstallPath -ErrorAction SilentlyContinue | 
                    Where-Object { $_.DisplayName -like "*Google Chrome*" -and $_.DisplayVersion }
                
                foreach ($entry in $chromeEntries) {
                    try {
                        $regVersion = [version]$entry.DisplayVersion
                        if ($regVersion -ge $minimumVersion) {
                            $detected = $true
                            $installedVersion = $regVersion
                            Write-Output "Google Chrome $regVersion detected via uninstall registry (meets minimum requirement $minimumVersion)"
                            break
                        }
                    }
                    catch {
                        # Skip entries with invalid version formats
                        continue
                    }
                }
                
                if ($detected) { break }
            }
        }
    }
    catch {
        Write-Output "Error checking registry for Chrome installation: $($_.Exception.Message)"
    }
}

# Return result based on detection
if ($detected) {
    exit 0
} else {
    if ($installedVersion) {
        Write-Output "Google Chrome $installedVersion detected but does not meet minimum requirement $minimumVersion"
    } else {
        Write-Output "Google Chrome $minimumVersion or higher NOT detected"
    }
    exit 1
}