<#
    .SYNOPSIS
 
    Takes all the actions necessary to prepare a Windows machine for use. The final use of the machine depends on the Chef cookbook that is
    provided.
 
 
    .DESCRIPTION
 
    The Install-ApplicationsOnWindowsWithChef script takes all the actions necessary to prepare a Windows machine for use.


    .PARAMETER configurationDirectory

    The directory in which all the installer packages and cookbooks can be found. It is expected that the cookbooks are stored
    in a 'cookbooks' sub-directory of the configurationDirectory.


    .PARAMETER logDirectory

    The directory in which all the logs should be stored.


    .PARAMETER cookbookName

    The name of the cookbook that should be used to configure the current machine.
 
 
    .EXAMPLE
 
    Install-ApplicationsOnWindowsWithChef -configurationDirectory "c:\configuration" -logDirectory "c:\logs" -cookbookName "myCookbook"
#>
[CmdletBinding()]
param(
    [string] $configurationDirectory = "c:\configuration",
    [string] $logDirectory          = "c:\logs",
    [string] $cookbookName          = "jenkinsmaster"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $configurationDirectory))
{
    New-Item -Path $configurationDirectory -ItemType Directory
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
& choco install ruby -version 2.0.0.57600

# Patch PATH for ruby
$rubyPath = "C:\tools\ruby200"
$env:PATH += ";$rubyPath\bin"

# install ruby2.devkit
Write-Output "Installing ruby2.devkit via chocolatey ..."
& choco install ruby2.devkit -version 4.7.2.2013022402

# patch devkit config
Write-Output "Patching ruby devkit config ..."
Add-Content -Path "C:\tools\DevKit2\config.yml" -Value " - $rubyPath"

# rerun devkit install stuff
Write-Output "Updating ruby with DevKit ..."
$currentPath = $pwd
try 
{
    sl "C:\tools\DevKit2\"
    & ruby "dk.rb" install
}
finally
{
    sl $currentPath
}

# patch the SSL certs
# Based on: http://stackoverflow.com/a/16134586/539846
$rubyCertDir = "c:\tools\rubycerts"
if (-not (Test-Path $rubyCertDir))
{
    New-Item -Path $rubyCertDir -ItemType Directory | Out-Null
}

$rubyCertFile = Join-Path $rubyCertDir "cacert.pem"
Invoke-WebRequest -Uri "http://curl.haxx.se/ca/cacert.pem" -OutFile $rubyCertFile -Verbose
Unblock-File -Path $rubyCertFile

# Permanently set the environment variable for the machine
[Environment]::SetEnvironmentVariable("SSL_CERT_FILE", "$rubyCertFile", "Machine")

# But also set it for the current process because environment variables aren't reloaded
$env:SSL_CERT_FILE = $rubyCertFile

Write-Output ("Environment variable SSL_CERT_FILE set to: " + $env:SSL_CERT_FILE)

# Temporarily rename the rake binaries because one of the gems will try to install rake which will
# lead to the whole process stopping while waiting for the user to approve that change. Hence we 
# approve that change now by renaming the rake binaries
Write-Output "Renaming rake binaries ..."
Rename-Item -Path "$rubyPath\bin\rake" -NewName "rake-old" -Force
Rename-Item -Path "$rubyPath\bin\rake.bat" -NewName "rake-old.bat" -Force

# load gems.
# Do this in a try..catch..finally so that we can continue even if there are errors because some of the gem installs 
# raise warnings that Powershell considers to be fatal errors, e.g. the ffi-yajl gem produces C compiler warnings
# that Powershell takes far too seriously. So we just supress the whole thing and we'll see if it works later.
try
{
    $ErrorActionPreference = "SilentlyContinue"

    Write-Output "Installing win32-process gem ..."
    & gem install win32-process --version 0.7.4 --no-document --conservative --minimal-deps --verbose

    Write-Output "Installing win32-nio gem ..."
    & gem install win32-nio --version 0.1.3 --no-document --conservative --minimal-deps --verbose

    Write-Output "Installing win32-service gem ..."
    & gem install win32-service --version 0.8.6 --no-document --conservative --minimal-deps --verbose

    Write-Output "Installing win32-eventlog gem ..."
    & gem install win32-eventlog --version 0.6.2 --no-document --conservative --minimal-deps --verbose

    Write-Output "Installing windows-pr gem ..."
    & gem install windows-pr --version 1.2.4 --no-document --conservative --minimal-deps --verbose

    Write-Output "Installing chef gem ..."
    & gem install chef --version 12.0.1 --no-document --conservative --minimal-deps --verbose
}
catch 
{
    Write-Output ("Failed to install gems. Error was: " + $_.Exception.ToString())
}
finally
{
    $ErrorActionPreference = "Stop"
}


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
    Set-Content -Path $chefConfig -Value ('cookbook_path ["' + $configurationDirectory + '/cookbooks"]')

    # Make a copy of the config for debugging purposes
    Copy-Item $chefConfig $logDirectory
}

Write-Output "Running chef-client ..."
try 
{
    & chef-client -z -o $cookbookName    
}
catch 
{
    Write-Output ("chef-client failed. Error was: " + $_.Exception.ToString())
}

if (($LastExitCode -ne $null) -and ($LastExitCode -ne 0))
{
    $userProfile = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::UserProfile)
    $chefPath = "$userProfile\.chef\local-mode-cache\cache"
    if (Test-Path $chefPath)
    {
        Get-ChildItem -Path $chefPath -Recurse -Force | Copy-Item -Destination $logDirectory
    }

    throw "Chef-client failed. Exit code: $LastExitCode"
}

Write-Output "Chef-client completed."