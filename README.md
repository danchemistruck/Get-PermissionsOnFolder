<#
	.SYNOPSIS
	Exports Directory Permissions to be used for cross forest migration. Collects all permissions on the root folder and only uninherited permissions on subdirectories. Individual files are excluded as well.
	
	.DESCRIPTION
    Author: Dan Chemistruck
    All Rights Reserved.
    Run from PowerShell as user with full permissions to the NTFS directory. Computer must have the ActiveDirectory module installed.
    	
	.PARAMETER DirPath
	Leave blank for the current directory, or specify a directory, or specify a CSV file with the column header: DirPath

    .PARAMETER ExportPath
	Directory where CSV files will be saved.
	
	.EXAMPLE
	Get-PermissionsOnFolder.ps1 -DirPath C:\Temp\ -ExportPath C:\Temp\Export
	
    .EXAMPLE
	Get-PermissionsOnFolder.ps1 -DirPath C:\Temp\Directories.csv -ExportPath C:\Temp\Export
   	
    .EXAMPLE
	Get-PermissionsOnFolder.ps1 -ExportPath C:\Temp\Export

    .NOTES
    This script requires the NTFSSecurity module, available here: https://github.com/raandree/NTFSSecurity
    To install, run:
        Install-Module -Name NTFSSecurity

    To install the activedirectory module on Windows 10, run:
        Add-WindowsCapability –online –Name “Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0”

    To install activeDirectory Module on Windows 11, run:
        Get-WindowsCapability -Name Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0 -Online | Add-WindowsCapability -Online

    The export file contains the following headers:
    AccountType	Name	FullName	InheritanceEnabled	InheritedFrom	AccessControlType	AccessRights	Account	InheritanceFlags	IsInherited	PropagationFlags
#>
