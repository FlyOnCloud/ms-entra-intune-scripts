# Win_Clean_EnrollmentID.ps1

## Overview

**Win_Clean_EnrollmentID.ps1** is a PowerShell script to automate the cleanup of Microsoft Intune MDM enrollment on a Windows device.  
It removes all scheduled tasks, registry keys, and certificates associated with the current Intune MDM enrollment.  
Optionally, it can also trigger a re-enrollment of the device into Intune using the built-in Windows enrollment tool.

---

## Features

- **Unregisters all Intune-related scheduled tasks** for the current enrollment.
- **Deletes the Intune enrollment task folder** from Task Scheduler.
- **Removes all registry keys** related to the specified Intune Enrollment ID.
- **Deletes the Intune MDM device certificate** from the local machine store.
- **(Optional)** Triggers device re-enrollment into Intune MDM.

---

## Usage

1. **Run the script as Administrator** on the target Windows device:
    ```powershell
    .\Win_Clean_EnrollmentID.ps1
    ```

2. The script will:
    - Detect the current Intune Enrollment ID.
    - Remove all related scheduled tasks and folders.
    - Clean up all related registry keys.
    - Remove the Intune MDM device certificate.
    - *(Optional)* Attempt to re-enroll the device using `deviceenroller.exe`.

---

## Optional: Re-enrollment

To enable automatic re-enrollment after cleanup, **uncomment** the following section at the end of the script:

```powershell
if (Test-Path $enrollerPath) {
    $p = Start-Process -FilePath $enrollerPath -ArgumentList @("/c", "/AutoEnrollMDM") -PassThru
    if ($p.HasExited) {
        Write-Output("{0} - Intune Re-enrollment successfully initiated")
    }
}
```

---

## Requirements

- Windows device joined to Azure AD and enrolled in Intune MDM
- PowerShell running as Administrator

---

## Notes

- The script is intended for use on the **local machine** only.
- Use with caution: This will remove all traces of the current Intune MDM enrollment.
- After cleanup, you may need to re-enroll the device to restore management.

---

## Disclaimer

This script is provided "as is" without warranty of any kind.  
Use at your own risk.  
Modifying or removing Intune MDM enrollment may affect device management, compliance, and access to corporate resources.  
Test thoroughly in a non-production environment before using in production.  
The author is not responsible for any damage or data loss resulting from the use of this script.

---

## Credits

- Author: Bogdan Guinea
- Inspired by: [sysopsbits.com](https://sysopsbits.com/re-enrolling-a-workstation-into-microsoft-intune-using-powershell/)

---
