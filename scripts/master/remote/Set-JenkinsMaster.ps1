<#
    .SYNOPSIS
 
    Takes all the actions necessary to prepare a Windows machine for use as a Jenkins master.
 
 
    .DESCRIPTION
 
    The Set-JenkinsMaster script takes all the actions necessary to prepare a Windows machine for use as a Jenkins master
 
 
    .EXAMPLE
 
    Set-JenkinsMaster
#>
[CmdletBinding()]
param()

$dir = "c:\temp"
if (-not (Test-Path $dir))
{
    New-Item -Path $dir -ItemType Directory
}

Set-Content -Value "This is a test" -Path (Join-Path $dir "myfile.txt")