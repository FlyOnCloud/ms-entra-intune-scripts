<#
.SYNOPSIS
Creates a folder and writes an XML file with specified content.

.DESCRIPTION
This script checks for the existence of a folder, creates it if it doesn't exist,
and writes an XML file with predefined content into that folder.

.PARAMETER TargetFolder
The folder path where the XML file will be created.

.PARAMETER FileName
The name of the XML file to create.

.EXAMPLE
.\Win_Create_XML_File.ps1 -TargetFolder "C:\XML" -FileName "myfile.xml"

.NOTES
Author: BGU
Date: 30.09.25
Version: 1.1
Rename the parameters as needed. For example, you can change the folder path and file name.
#>

param (
    [string]$TargetFolder = "C:\XML",
    [string]$FileName = "myfile.xml"
)

try {
    # Create folder if it doesn't exist
    if (!(Test-Path $TargetFolder)) {
        New-Item -Path $TargetFolder -ItemType Directory | Out-Null
        Write-Output "Created folder: $TargetFolder"
    } else {
        Write-Output "Folder already exists: $TargetFolder"
    }

    # Define XML content as a string
    $xmlContent = @"
<Settings>
    <Option name="Example" value="True" />
</Settings>
"@

    # Write XML content to file
    $destinationFile = Join-Path $TargetFolder $FileName
    $xmlContent | Out-File -FilePath $destinationFile -Encoding UTF8
    Write-Output "XML file created at: $destinationFile"
}
catch {
    Write-Error "Error: $($_.Exception.Message)"
}