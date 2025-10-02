<#
.SYNOPSIS
    Checks for the existence of the registry path "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate" and flags non-compliance if found.

.DESCRIPTION
    This script is used to detect the presence of the Windows Update policy registry key under HKLM. If the registry path exists, 
    the device is considered non-compliant and requires remediation by deleting the registry key.

.NOTES
    Author: BGU
    Date: 02.10.2025
    Version: 1.0
    Detection Script for Intune Proactive Remediation
    This is only a example, feel free to modify it to your needs.
#>

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

# Check if the registry path exists
if (Test-Path -Path $RegPath) {
    Write-Output "Reg. found - Non-compliant"
    exit 1  # Non-compliant - remediation needed
} else {
    Write-Output "Reg. not found - Compliant"
    exit 0  # Compliant - no remediation needed
}