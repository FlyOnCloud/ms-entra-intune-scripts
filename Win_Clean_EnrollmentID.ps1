<#
.SYNOPSIS
    Cleans up Intune MDM enrollment on a Windows device and optionally initiates re-enrollment.

.DESCRIPTION
    This script automates the process of unenrolling a Windows workstation from Microsoft Intune MDM.
    It removes scheduled tasks, registry keys, and certificates associated with the current Intune enrollment.
    Optionally, it can trigger device re-enrollment using deviceenroller.exe.

.PARAMETER None
    The script does not accept parameters. It operates on the local machine.

.NOTES
    Author: BGU
    Date: 05.08.2025
    Version: 1.0
    Kudos to : https://sysopsbits.com/re-enrolling-a-workstation-into-microsoft-intune-using-powershell/
    File: Win_Clean_EnrollmentID.ps1

.EXAMPLE
    .\Win_Clean_EnrollmentID.ps1
    Runs the script to clean up Intune MDM enrollment and optionally trigger re-enrollment.

#>

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
$cert = Get-ChildItem Cert:\LocalMachine\My | ?{$_.Issuer -eq "CN=Microsoft Intune MDM Device CA"}

try{
    $enrollmentId = Get-ItemPropertyValue "HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger" -Name "CurrentEnrollmentId"
}catch{
    Write-Output "Inutune Enrollment Id not found. Exit 1"; exit 1
}

Write-Output "$($Env:COMPUTERNAME) - The Intune Enrollment ID is $enrollmentId"

# unregister all tasks within the enrollment folder
$intuneScheduledTasks = Get-ScheduledTask -TaskPath "\Microsoft\Windows\EnterpriseMgmt\$enrollmentId\" -ErrorAction SilentlyContinue

if($null -eq $intuneScheduledTasks){ 
    Write-Output("Task folder {0} does not exist. Exit 1" -f "\Microsoft\Windows\EnterpriseMgmt\$enrollmentId\"); exit 1
}

foreach($task in $intuneScheduledTasks){

    Write-Output("Unregistering scheduled task - {0}" -f $task.TaskName)
    Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false
}

# delete the enrollment task folder, 0 
$scheduleObj = New-Object -ComObject Schedule.Service
$scheduleObj.Connect()
$rootEnrollmentFolder = $scheduleObj.GetFolder("\Microsoft\Windows\EnterpriseMgmt")
$rootEnrollmentFolder.DeleteFolder($enrollmentId, 0)


# delete the registry keys with the enrollment ID and all sub keys
foreach($path in $regArr){

    $targetPath = Join-Path $path $enrollmentId
    if(test-path -Path $targetPath){
        Write-Output("Removing {0} and all sub-keys/items" -f $targetPath)
        Remove-Item -Path $targetPath -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
    }
}

if($cert){ 
    Write-Output("{0}" -f $cert.Issuer)
    $cert | remove-item -Force -ErrorAction SilentlyContinue
}

# Optionally, re-enroll the device
<# if(test-path $enrollerPath){
    $p = Start-Process -FilePath $enrollerPath -ArgumentList @("/c", "/AutoEnrollMDM") -PassThru
    if($p.HasExited){
        Write-Output("{0} - Intune Re-enrollment successfully initiated")
     }
}#>