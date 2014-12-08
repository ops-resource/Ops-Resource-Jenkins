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
Write-Output "Installing chocolatey ..."
Invoke-Expression ((new-object net.webclient).DownloadString('https://chocolatey.org/install.ps1'))

# Add chocolatey to the path
$env:ChocolateyInstall = "C:\ProgramData\chocolatey"

# Install ruby
Write-Output "Installing ruby via chocolatey ..."
& choco install ruby -version 2.1.3.0

# Patch PATH for ruby
$env:PATH += ";C:\tools\ruby213\bin"

# install ruby2.devkit
Write-Output "Installing ruby2.devkit via chocolatey ..."
& choco install ruby2.devkit -version 4.7.2.2013022402

# patch devkit config
Write-Output "Patching ruby devkit config ..."
Add-Content -Path "C:\tools\DevKit2\config.yml"  -Value " - C:\tools\ruby213"

# rerun devkit install stuff
Write-Output "Updating ruby with DevKit ..."
& ruby "C:\tools\DevKit2\dk.rb" install

# load gems
Write-Output "Installing win32-process gem ..."
& gem install win32-process --version 0.7.4

Write-Output "Installing win32-service gem ..."
& gem install win32-service --version 0.8.6

Write-Output "Installing chef gem ..."
& gem install chef --version 12.0.0


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

Write-Output "Running chef-client ..."
& chef-client -z -o $cookbookName
if (($LastExitCode -ne $null) -and ($LastExitCode -ne 0))
{
    throw "Chef-client failed. Exit code: $LastExitCode"
}

Write-Output "Chef-client completed."