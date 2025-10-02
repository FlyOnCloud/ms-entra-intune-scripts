<#
.SYNOPSIS
    Checks for the existence of the registry path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" and indicates non-compliance if found.

.DESCRIPTION
    This script is intended for compliance remediation. If the specified registry path is present, 
    the device is considered non-compliant. Remediation involves deleting the registry key to restore compliance.

.NOTES
    Author: BGU
    Date: 02.10.2025
    Version: 1.0
    Remediation Script for Intune Proactive Remediation
    This is only a example, feel free to modify it to your needs.
    Ensure appropriate permissions before attempting to delete registry keys.
#>

try { 
    # Delete the registry key if it exists
    $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
    Remove-Item -Path $regPath -Recurse -Force -ErrorAction Stop
    Write-Output "Reg. deleted successfully"

    #Check if the key still exists
    if (Test-Path $regPath) {
        Write-Output "Reg. still exists after deletion attempt."
        # Exit with code 1 to indicate failure
        exit 1
    }

    # Exit with code 0 to indicate success
    exit 0
} catch {
    Write-Output "Failed to delete reg: $_"
    # Exit with code 1 to indicate failure
    exit 1
}