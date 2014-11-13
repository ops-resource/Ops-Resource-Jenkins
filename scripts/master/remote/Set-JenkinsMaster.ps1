<#
    .SYNOPSIS
 
    Takes all the actions necessary to prepare a Windows machine for use as a Jenkins master.
 
 
    .DESCRIPTION
 
    The Set-JenkinsMaster script takes all the actions necessary to prepare a Windows machine for use as a Jenkins master
 
 
    .EXAMPLE
 
    Set-JenkinsMaster
#>
[CmdletBinding()]
param(
    [string] $installationDirectory = "c:\installers",
    [string] $logDirectory          = "c:\logs",
    [string] $cookbookName          = "jenkinsmaster"
)

# The directory that contains all the installation files
$installationDirectory = $PSScriptRoot

# Download chef client. Note that this is obviously hard-coded but for now it will work. Later on we'll make this a configuration option
$chefClientInstallFile = "chef-windows-11.16.4-1.windows.msi"
$chefClientDownloadUrl = "https://opscode-omnibus-packages.s3.amazonaws.com/windows/2008r2/x86_64/" + $chefClientInstallFile
$chefClientInstall = Join-Path $installationDirectory $chefClientInstallFile
Invoke-WebRequest -Uri $chefClientDownloadUrl -OutFile $chefClientInstall

# Install the chef client
Unblock-File -Path $chefClientInstall

$chefInstallLogFile = Join-Path $logDirectory "chef.install.log"
& msiexec.exe /i "$chefClientInstall" /Lime! "$chefInstallLogFile" /qn
try 
{
    # Set the path for the cookbooks
    $chefConfigDir = Join-Path $env:UserProfile ".chef"
    if (-not (Test-Path $chefConfigDir))
    {
        Write-Output "Creating the chef configuration directory ..."
        New-Item -Path $chefConfigDir -ItemType Directory | Out-Null
    }

    $chefConfig = Join-Path $chefConfigDir 'knife.rb'
    if (-not (Test-Path $chefConfig))
    {
        Write-Output "Creating the chef configuration file"
        Set-Content -Path $chefConfig -Value ('cookbook_path ["' + $installationDirectory + '/cookbooks"]')

        # Make a copy of the config for debugging purposes
        Copy-Item $chefConfig $logDirectory
    }

    # Execute the chef client as: chef-client -z -o $cookbookname
    $chefClient = "c:\opscode\chef\bin\chef-client.bat"
    & $chefClient -z -o $cookbookName
}
finally
{
    # delete chef from the machine
    $chefUninstallLogFile = Join-Path $logDirectory "chef.uninstall.log"
    & msiexec.exe /x "$chefClientInstall" /Lime! "$chefUninstallLogFile" /qn
}