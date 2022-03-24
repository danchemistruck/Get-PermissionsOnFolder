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
[CmdletBinding()]
Param(
	[Parameter(Mandatory=$false,
			HelpMessage="Parent Directory")]
	[Alias('WorkingPath')]
	[string]$DirPath,
		
	[Parameter(Mandatory=$True,
			HelpMessage="Directory to output files to")]
			[String]$ExportPath
)
import-module NTFSSecurity
import-module ActiveDirectory

#Sets the Directory to query for permissions
#Import a CSV
if($DirPath.Substring($DirPath.Length - 3) -eq "csv"){
    $Directory = import-csv $DirPath
}
#Otherwise use the directory provided by parameter
elseif (test-path2 $DirPath){
    $Directory = @{ 'DirPath' = $DirPath}
}
#Otherwise us the current directory
else{
    $Directory = @{ 'DirPath' = $pwd}
}
$ErrorLog = Join-Path $ExportPath ACL-ErrorPath.csv
$Permissions = Join-Path $ExportPath ACL-FolderPermissions.csv
$GroupInfo = Join-Path $ExportPath ACL-GroupData.csv
$GroupMembers = Join-Path $ExportPath ACL-GroupMembers.csv
$GroupErrors = Join-Path $ExportPath ACL-ErrorGroups.csv

if (!(test-path2 $ExportPath)){
    New-Item -Path $ExportPath -ItemType directory
}

#Gets Permissions
$i=0
foreach ($WorkDir in $Directory){
    $LoopPath = $WorkDir.dirpath

    [INT]$CurrentOperation = ($i/$Directory.count)*100
    Write-Progress -Activity "Getting ACL for $LoopPath" -PercentComplete $CurrentOperation
    Try{
#       Write-Progress -Activity "Discovering Folder Tree"
        Get-NTFSAccess $LoopPath -ErrorAction stop -ErrorVariable ntfserr | export-csv $Permissions -nti -append -force
# Doesn't like the piped write-progress       Get-ChildItem2 -recurse $LoopPath -Directory| Get-NTFSAccess -ExcludeInherited  -ErrorAction stop -ErrorVariable childerr;%{Write-Progress -id 1 -Activity "Working on $_"} | export-csv $Permissions -nti -append -force
        write-host "Getting directory structure for $LoopPath"
        $tree = Get-ChildItem2 -recurse $LoopPath -Directory
        write-host "Getting Permissions for $LoopPath"
        $tree | Get-NTFSAccess -ExcludeInherited -ErrorAction stop -ErrorVariable childerr| export-csv $Permissions -nti -append -force
     }
    Catch{
        #Gathers Error Log information and outputs to CSV.
        $errorObject = new-object PSObject
        Write-host Error with $LoopPath -ForegroundColor Red 
        $errorObject| add-member -membertype NoteProperty -name "Path" -Value $LoopPath
        If($NTFSerr -ne $null){
            Write-host NTFS error $ntfserr.message -ForegroundColor Red 
            $errorObject| add-member -membertype NoteProperty -name "NTFS Error" -Value $NTFSerr.message
        }
        If($Childerr -ne $null){
            Write-host Child error $Childerr.message -ForegroundColor Red
            $errorObject| add-member -membertype NoteProperty -name "Child Error" -Value $Childerr.message
        } 
        $errorObject | export-csv $ErrorLog -nti -append -force
    }
    $i++
}



#Gets all the unique groups from the export above and generates a group/user list to be recreated in target domain.
$i=0
$groups = (import-csv $Permissions  | where {$_.AccountType -eq "group"}| sort Account -unique)
foreach ($group in $groups)
{ 
    [INT]$CurrentOperation = ($i/$Groups.count)*100
    [String]$Grp = $group.account.split("{\}")[1]
    Write-Progress -Activity "Getting Group Members for $grp" -CurrentOperation "Getting AD Members" -PercentComplete $CurrentOperation
    
    Try{
        Get-ADGroup $Grp -properties * -ErrorAction Continue -ErrorVariable GroupError | export-csv $GroupInfo -nti -append -force
        Get-ADGroupMember -Id $Grp -recursive -ErrorAction Continue -ErrorVariable GroupMemberError | select @{Expression={$group.account.split("{\}")[1]};Label="Group"},samaccountname,name | Export-CSV $GroupMembers -NoTypeInformation -append -force
    }
    Catch{
        Write-host Get Group error $group.account.split("{\}")[1] $GroupError.message -ForegroundColor Red
        $errorObject = new-object PSObject
        $errorObject| add-member -membertype NoteProperty -name "Group" -Value $Group.account.split("{\}")[1]
        $errorObject| add-member -membertype NoteProperty -name "Group Error" -Value $GroupError.message
        $errorObject| add-member -membertype NoteProperty -name "Group Member Error" -Value $GroupMemberError.message
        $errorObject | export-csv $GroupErrors -nti -append -force
    }
    $i++
}