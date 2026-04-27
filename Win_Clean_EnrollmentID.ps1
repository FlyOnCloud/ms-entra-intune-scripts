<#
.SYNOPSIS
    Performs a comprehensive cleanup of Intune MDM enrollment artifacts on a Windows device.

.DESCRIPTION
    This script logs its actions to a transcript file and attempts to remove all traces of Intune MDM enrollment, including:
    Scheduled tasks related to Intune MDM enrollment.
    Registry keys and values associated with Intune MDM.
    Certificates issued by "Microsoft Intune MDM Device CA".
    Additional EnterpriseMgmt scheduled tasks.
    The script handles both cases where an Enrollment ID is found and where it is missing, performing general cleanup if necessary.
    Optionally, the script can initiate device re-enrollment if no major errors occurred (code is commented out).

.PARAMETER None
    All required paths and values are determined automatically.

.NOTES
    Author: BGU
    Date: 16.09.2025
    Version 2.0
    Requires administrative privileges.
    Designed for troubleshooting or resetting Intune MDM enrollment on Windows devices.
    Log file is saved to C:\Windows\Temp with a timestamp.
    Exits with code 0 on success, 1 on warnings/errors.

.EXAMPLE
    .\Win_Clean_EnrollmentID_v02.ps1

    Runs the Intune MDM cleanup process and logs actions to a transcript file.

#>
# Start transcript logging to C:\Windows\Temp
$logPath = "C:\Windows\Temp\Win_Clean_EnrollmentID_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
Start-Transcript -Path $logPath -Force

try {
    Write-Output "Starting Intune MDM Cleanup Script on $($env:COMPUTERNAME) at $(Get-Date)"
    Write-Output "Log file: $logPath"
    Write-Output "----------------------------------------"

    $regArr = @(
        "HKLM:\SOFTWARE\Microsoft\Enrollments\", 
        "HKLM:\SOFTWARE\Microsoft\Enrollments\Status\", 
        "HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\", 
        "HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\", 
        "HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\", 
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\", 
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\", 
        "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\"
    )

    $enrollerPath = "$env:windir\system32\deviceenroller.exe"
    $cert = Get-ChildItem Cert:\LocalMachine\My | ? { $_.Issuer -eq "CN=Microsoft Intune MDM Device CA" }
    
    # Initialize variables for tracking issues
    $hasErrors = $false
    $enrollmentId = $null

    # Try to get enrollment ID but don't exit if not found
    try {
        $enrollmentId = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger" -Name "CurrentEnrollmentId"
        Write-Output "$($Env:COMPUTERNAME) - The Intune Enrollment ID is $enrollmentId"
    }
    catch {
        Write-Output "Warning: Intune Enrollment Id not found. Continuing with general cleanup..."
        $hasErrors = $true
    }

    # Only try to clean scheduled tasks if we have an enrollment ID
    if ($enrollmentId) {
        # unregister all tasks within the enrollment folder
        $intuneScheduledTasks = Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$enrollmentId\" -ErrorAction SilentlyContinue

        if ($null -eq $intuneScheduledTasks) { 
            Write-Output("Warning: Task folder {0} does not exist. Skipping task cleanup..." -f "\Microsoft\Windows\EnterpriseMgmt\$enrollmentId\")
            $hasErrors = $true
        }
        else {
            foreach ($task in $intuneScheduledTasks) {
                try {
                    Write-Output("Unregistering scheduled task - {0}" -f $task.TaskName)
                    Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false
                }
                catch {
                    Write-Output("Warning: Failed to unregister task {0}: {1}" -f $task.TaskName, $_.Exception.Message)
                    $hasErrors = $true
                }
            }

            # delete the enrollment task folder
            try {
                Write-Output "Deleting enrollment task folder..."
                $scheduleObj = New-Object -ComObject Schedule.Service
                $scheduleObj.Connect()
                $rootEnrollmentFolder = $scheduleObj.GetFolder("\Microsoft\Windows\EnterpriseMgmt")
                $rootEnrollmentFolder.DeleteFolder($enrollmentId, 0)
                Write-Output "Successfully deleted enrollment task folder"
            }
            catch {
                Write-Output("Warning: Failed to delete enrollment task folder: {0}" -f $_.Exception.Message)
                $hasErrors = $true
            }
        }
    }
    else {
        Write-Output "Skipping scheduled task cleanup due to missing enrollment ID"
    }

    # Always attempt registry cleanup (even without enrollment ID)
    Write-Output "Cleaning up registry keys..."
    if ($enrollmentId) {
        # Clean specific enrollment ID paths
        foreach ($path in $regArr) {
            $targetPath = Join-Path $path $enrollmentId
            if (test-path -Path $targetPath) {
                try {
                    Write-Output("Removing {0} and all sub-keys/items" -f $targetPath)
                    Remove-Item -Path $targetPath -Recurse -Force -ErrorAction Stop
                }
                catch {
                    Write-Output("Warning: Failed to remove {0}: {1}" -f $targetPath, $_.Exception.Message)
                    $hasErrors = $true
                }
            }
            else {
                Write-Output("Registry path not found: {0}" -f $targetPath)
            }
        }
    }
    else {
        # Clean all enrollment-related registry entries when no specific ID is found
        Write-Output "No enrollment ID found - performing general Intune registry cleanup..."
        foreach ($path in $regArr) {
            if (test-path -Path $path) {
                try {
                    # Get all subfolders/entries under this path
                    $subItems = Get-ChildItem -Path $path -ErrorAction SilentlyContinue
                    foreach ($item in $subItems) {
                        Write-Output("Removing {0}" -f $item.PSPath)
                        Remove-Item -Path $item.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
                catch {
                    Write-Output("Warning: Failed to clean {0}: {1}" -f $path, $_.Exception.Message)
                    $hasErrors = $true
                }
            }
        }
    }

    # Always attempt certificate cleanup
    if ($cert) { 
        try {
            Write-Output("Removing certificate: {0}" -f $cert.Issuer)
            $cert | remove-item -Force -ErrorAction Stop
            Write-Output "Successfully removed Intune MDM certificate"
        }
        catch {
            Write-Output("Warning: Failed to remove certificate: {0}" -f $_.Exception.Message)
            $hasErrors = $true
        }
    }
    else {
        Write-Output "No Intune MDM certificates found to remove"
    }

    # Additional cleanup - remove any remaining Intune-related items
    Write-Output "Performing additional cleanup checks..."
    
    # Clean up any remaining EnterpriseMgmt folders
    try {
        $entMgmtPath = "\Microsoft\Windows\EnterpriseMgmt\"
        $allEntMgmtTasks = Get-ScheduledTask -TaskPath "$entMgmtPath*" -ErrorAction SilentlyContinue
        if ($allEntMgmtTasks) {
            Write-Output "Found additional EnterpriseMgmt tasks to clean up..."
            foreach ($task in $allEntMgmtTasks) {
                try {
                    Write-Output("Removing additional task: {0}" -f $task.TaskName)
                    Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false
                }
                catch {
                    Write-Output("Warning: Failed to remove task {0}" -f $task.TaskName)
                }
            }
        }
    }
    catch {
        Write-Output("Warning: Error during additional task cleanup: {0}" -f $_.Exception.Message)
    }

    # Optionally, re-enroll the device (only if no major errors occurred)
    <# if(!$hasErrors -and (test-path $enrollerPath)){
        Write-Output "Starting re-enrollment process..."
        try {
            $p = Start-Process -FilePath $enrollerPath -ArgumentList @("/c", "/AutoEnrollMDM") -PassThru -Wait
            if($p.ExitCode -eq 0){
                Write-Output("{0} - Intune Re-enrollment successfully initiated" -f $env:COMPUTERNAME)
            } else {
                Write-Output("Warning: Re-enrollment process returned exit code: {0}" -f $p.ExitCode)
                $hasErrors = $true
            }
        } catch {
            Write-Output("Warning: Failed to start re-enrollment: {0}" -f $_.Exception.Message)
            $hasErrors = $true
        }
    }#>

    Write-Output "----------------------------------------"
    if ($hasErrors) {
        Write-Output "Intune MDM Cleanup completed with warnings at $(Get-Date)"
        Write-Output "Some cleanup operations encountered issues - check log for details"
        Write-Output "Log saved to: $logPath"
        # Don't exit with error here - let the script complete and return appropriate code at the end
    }
    else {
        Write-Output "Intune MDM Cleanup completed successfully at $(Get-Date)"
        Write-Output "Log saved to: $logPath"
    }

    # Return appropriate exit code based on whether errors occurred
    if ($hasErrors) {
        Write-Output "Exiting with code 1 due to warnings/errors during cleanup"
        $exitCode = 1
    }
    else {
        Write-Output "Exiting with code 0 - cleanup completed successfully"
        $exitCode = 0
    }

}
catch {
    Write-Error "Critical error occurred: $($_.Exception.Message)"
    Write-Output "Script failed at $(Get-Date)"
    $exitCode = 1
}
finally {
    # Always stop transcript
    try {
        Stop-Transcript
    }
    catch {
        # Ignore transcript stop errors
    }
    
    # Exit with appropriate code
    if ($exitCode) {
        exit $exitCode
    }
    else {
        exit 1  # Default to error if exitCode not set
    }
}