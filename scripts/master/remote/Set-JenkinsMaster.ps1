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

function Install-Msi
{
    param(
        [string] $msiFile,
        [string] $logFile
    )

    Start-Process -FilePath "msiExec" -ArgumentList "/i $msiFile /Lime! $logFile /qn" -Wait
}

function Uninstall-Msi
{
    param(
        [string] $msiFile,
        [string] $logFile
    )

    Start-Process -FilePath "msiExec" -ArgumentList "/x $msiFile /Lime! $logFile /qn" -Wait
}

# The directory that contains all the installation files
$installationDirectory = $PSScriptRoot

if (-not (Test-Path $installationDirectory))
{
    New-Item -Path $installationDirectory -ItemType Directory
}

if (-not (Test-Path $logDirectory))
{
    New-Item -Path $logDirectory -ItemType Directory
}

# Download chef client. Note that this is obviously hard-coded but for now it will work. Later on we'll make this a configuration option
Write-Output "Downloading chef installer ..."
$chefClientInstallFile = "chef-windows-11.16.4-1.windows.msi"
$chefClientDownloadUrl = "https://opscode-omnibus-packages.s3.amazonaws.com/windows/2008r2/x86_64/" + $chefClientInstallFile
$chefClientInstall = Join-Path $installationDirectory $chefClientInstallFile
Invoke-WebRequest -Uri $chefClientDownloadUrl -OutFile $chefClientInstall -Verbose

Write-Output "Chef download complete."
if (-not (Test-Path $chefClientInstall))
{
    throw 'Failed to download the chef installer.'
}

# Install the chef client
Unblock-File -Path $chefClientInstall

Write-Output "Installing chef from $chefClientInstall ..."
$chefInstallLogFile = Join-Path $logDirectory "chef.install.log"
Install-Msi -msiFile "$chefClientInstall" -logFile "$chefInstallLogFile"

if ($LastExitCode -ne 0)
{
    throw 'Failed to install chef.'
}

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

    $opscodePath = "c:\opscode"
    if (-not (Test-Path $opscodePath))
    {
        throw "Chef install path not found."
    }

    # Execute the chef client as: chef-client -z -o $cookbookname
    $chefClient = "c:\opscode\chef\bin\chef-client.bat"
    if (-not (Test-Path $chefClient))
    {
        throw "Chef client not found"
    }

    & $chefClient -z -o $cookbookName
}
finally
{
    Write-Output "Uninstalling chef ..."

    # delete chef from the machine
    $chefUninstallLogFile = Join-Path $logDirectory "chef.uninstall.log"
    Uninstall-Msi -msiFile $chefClientInstall -logFile $chefUninstallLogFile
}