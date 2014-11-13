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

# The directory that contains all the installation files
$installationDirectory = $PSScriptRoot

# Download chef client. Note that this is obviously hard-coded but for now it will work. Later on we'll make this a configuration option
$chefClientInstallFile = "chef-windows-11.16.4-1.windows.msi"
$chefClientDownloadUrl = "https://opscode-omnibus-packages.s3.amazonaws.com/windows/2008r2/x86_64/" + $chefClientInstallFile
$chefClientInstall = Join-Path $installationDirectory $chefClientInstallFile
Invoke-WebRequest -Uri $chefClientDownloadUrl -OutFile $chefClientInstall

# Install the chef client
Unblock-File -Path $chefClientInstall


& msiexec.exe /i "$chefClientInstall" /Lime! "$chefInstallLogFile" /qn
try 
{
    # Execute the chef client as: chef-client -z -o $cookbookname

    # Wait for chef to complete
    
}
finally
{
    # delete chef from the machine
    & msiexec.exe /x "$chefClientInstall" /Lime! "$chefUninstallLogFile" /qn
}