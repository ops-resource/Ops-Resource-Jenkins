<#
    .SYNOPSIS
 
    Takes all the actions necessary to prepare a Windows machine for use as a Jenkins master.
 
 
    .DESCRIPTION
 
    The Install-ApplicationsOnWindowsWithChef script takes all the actions necessary to prepare a Windows machine for use as a Jenkins master
 
 
    .EXAMPLE
 
    Install-ApplicationsOnWindowsWithChef
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

    $p = Start-Process -FilePath "msiExec.exe" -ArgumentList "/i $msiFile /Lime! $logFile /qn" -PassThru
    $p.WaitForExit()

    if ($p.ExitCode -ne 0)
    {
        throw "Failed to install: $msiFile"
    }
}

function Uninstall-Msi
{
    param(
        [string] $msiFile,
        [string] $logFile
    )

    $p = Start-Process -FilePath "msiExec.exe" -ArgumentList "/x $msiFile /Lime! $logFile /qn" -PassThru
    $p.WaitForExit()

    if ($p.ExitCode -ne 0)
    {
        throw "Failed to install: $msiFile"
    }
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


# Install Chocolatey

# Add chocolatey to the path
# Install ruby
# install ruby2.devkit
# patch devkit config
# rerun devkit install stuff

# load gems
# -chef
# -chef-zero
# -win32-process

# Run chef-zero and push the cookbook to it


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

    # Add the ruby path to the $env:PATH for the current session.
    $embeddedRubyPath = "$opscodePath\chef\embedded\bin"
    if (-not (Test-Path $embeddedRubyPath))
    {
        throw "Embedded ruby path not found."
    }

    $env:PATH += ";" + $embeddedRubyPath

    # Execute the chef client as: chef-client -z -o $cookbookname
    $chefClient = "$opscodePath\chef\bin\chef-client.bat"
    if (-not (Test-Path $chefClient))
    {
        throw "Chef client not found"
    }

    Write-Output "Running chef-client ..."
    & $chefClient -z -o $cookbookName
    if (($LastExitCode -ne $null) -and ($LastExitCode -ne 0))
    {
        throw "Chef-client failed. Exit code: $LastExitCode"
    }

    Write-Output "Chef-client completed."
}
finally
{
    Write-Output "Uninstalling chef ..."

    # delete chef from the machine
    $chefUninstallLogFile = Join-Path $logDirectory "chef.uninstall.log"
    Uninstall-Msi -msiFile $chefClientInstall -logFile $chefUninstallLogFile
}