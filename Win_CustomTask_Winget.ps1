<#
.SYNOPSIS
Winget Auto-Update Script with Task Scheduler Integration

.DESCRIPTION
This script creates a scheduled task to automatically update applications using winget.
It is designed for deployment via Intune to Windows 11 client machines.

.PARAMETER None
This script does not require any parameters.

.EXAMPLE
.\Win_CustomTask_Winget.ps1
Runs the script to create the scheduled task for winget auto-update.

.NOTES
Ensure winget is installed and available on the target system.
Administrator privileges may be required to create scheduled tasks.
BGU
Date: 26.09.2025
Version: 1.0
#>

# Script configuration
$TaskName = "CustomTask-WingetUpdate"
$LogPath = "C:\ProgramData\Logs\WingetUpdates"
$ScriptPath = "C:\ProgramData\Scripts\WingetUpdate.ps1"

$directories = @($LogPath, (Split-Path $ScriptPath))
foreach ($dir in $directories) {
    if (!(Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Write-Output "Created directory: $dir"
    }
}

# Create the winget update script
$WingetUpdateScript = @'
<#
Simple Winget Auto-Update Script
Logs to C:\ProgramData\Logs\WingetUpdates
#>

$LogFile = "C:\ProgramData\Logs\WingetUpdates\WingetUpdate_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

# Start logging
Start-Transcript -Path $LogFile

Write-Output "=== Winget Auto-Update Started at $(Get-Date) ==="
Write-Output "Computer: $env:COMPUTERNAME"

# Find winget executable - simple approach
$wingetPath = Get-ChildItem "${env:ProgramFiles}\WindowsApps\Microsoft.DesktopAppInstaller_*_x64__8wekyb3d8bbwe\winget.exe" -ErrorAction SilentlyContinue | Select-Object -First 1

if (!$wingetPath) {
    Write-Output "ERROR: Winget not found"
    Stop-Transcript
    exit 1
}

Write-Output "Found winget at: $($wingetPath.FullName)"

# Test winget
Write-Output "Testing winget..."
$version = & $wingetPath.FullName --version
Write-Output "Winget version: $version"

# Upgrade all packages
Write-Output "Starting package upgrades..."
$upgradeResult = & $wingetPath.FullName upgrade --all --silent --accept-package-agreements --accept-source-agreements --force
Write-Output "Upgrade completed"

Write-Output "=== Winget Auto-Update Completed at $(Get-Date) ==="
Stop-Transcript
'@

# Write the winget update script to disk
try {
    $WingetUpdateScript | Out-File -FilePath $ScriptPath -Encoding UTF8 -Force
    Write-Output "Created winget update script at: $ScriptPath"
}
catch {
    Write-Error "Failed to create winget script: $($_.Exception.Message)"
    exit 1
}

# Remove existing task if it exists
$existingTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existingTask) {
    Write-Output "Removing existing task: $TaskName"
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Create the scheduled task
try {
    # Task action
    $action = New-ScheduledTaskAction -Execute "PowerShell.exe" -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
    
    # Task triggers - Multiple triggers for flexibility
    $triggers = @()

    # Daily trigger at 3 PM
    $triggers += New-ScheduledTaskTrigger -Daily -At "15:00"
    
    # At startup (delayed)
    $triggers += New-ScheduledTaskTrigger -AtStartup
    
    # When user logs on (for user context updates)
    $triggers += New-ScheduledTaskTrigger -AtLogOn
    
    # Task settings
    $settings = New-ScheduledTaskSettingsSet `
        -AllowStartIfOnBatteries `
        -DontStopIfGoingOnBatteries `
        -StartWhenAvailable `
        -RunOnlyIfNetworkAvailable `
        -ExecutionTimeLimit (New-TimeSpan -Hours 1) `
        -RestartCount 2 `
        -RestartInterval (New-TimeSpan -Minutes 10)
    
    # Principal - Run as SYSTEM with highest privileges
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    
    # Task description
    $description = @"
Winget Auto-Update Task
Updates installed applications using Windows Package Manager (winget)
Deployed via Intune - BGU
Created: $(Get-Date)
Script: $ScriptPath
Logs: $LogPath
"@
    
    # Register the task with all triggers
    $task = Register-ScheduledTask `
        -TaskName $TaskName `
        -Action $action `
        -Trigger $triggers `
        -Settings $settings `
        -Principal $principal `
        -Description $description `
        -Force
    
    Write-Output "SUCCESS: Scheduled task '$TaskName' created successfully"
    Write-Output "Task will run daily at 3 PM, at startup, and at user logon"
    
    # Verify task creation
    $createdTask = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
    if ($createdTask) {
        Write-Output "Task verification: SUCCESS"
        Write-Output "Task State: $($createdTask.State)"
        
        # Get next run time
        $taskInfo = Get-ScheduledTaskInfo -TaskName $TaskName
        Write-Output "Next Run Time: $($taskInfo.NextRunTime)"
        
        # Test the task (optional - comment out if you don't want immediate execution)
        # Write-Output "Testing task execution..."
        # Start-ScheduledTask -TaskName $TaskName
        
    }
    else {
        Write-Error "Task verification: FAILED"
        exit 1
    }
    
}
catch {
    Write-Error "Failed to create scheduled task: $($_.Exception.Message)"
    exit 1
}

# Create a manual run script for administrators
$ManualRunScript = @"
@echo off
echo Running Winget Updates Manually...
PowerShell.exe -ExecutionPolicy Bypass -File "$ScriptPath"
pause
"@

$ManualRunPath = "C:\ProgramData\Scripts\RunWingetUpdate.bat"
try {
    $ManualRunScript | Out-File -FilePath $ManualRunPath -Encoding ASCII -Force
    Write-Output "Created manual run script at: $ManualRunPath"
}
catch {
    Write-Warning "Failed to create manual run script: $($_.Exception.Message)"
}

# Summary
Write-Output ""
Write-Output "=== DEPLOYMENT SUMMARY ==="
Write-Output "Task Name: $TaskName"
Write-Output "Script Location: $ScriptPath"
Write-Output "Log Directory: $LogPath"
Write-Output "Manual Run: $ManualRunPath"
Write-Output "Schedule: Daily at 3 PM, At Startup, At Logon"
Write-Output "Execution Context: SYSTEM account"
Write-Output "=========================="
Write-Output ""
Write-Output "Winget auto-update deployment completed successfully!"

exit 0