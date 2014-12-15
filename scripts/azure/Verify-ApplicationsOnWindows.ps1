<#
    .SYNOPSIS
 
    Executes the tests that verify whether the current machine has all the tools installed to allow it to work as a Windows Jenkins master.
 
 
    .DESCRIPTION
 
    The Verify-ApplicationsOnWindows script executes the tests that verify whether the current machine has all the tools installed to allow it to work as a Windows Jenkins master.
 
 
    .EXAMPLE
 
    Verify-ApplicationsOnWindows
#>
[CmdletBinding()]
param(
    [string] $testDirectory = "c:\tests",
    [string] $logDirectory  = "c:\logs"
)


Write-Output "Installing serverspec gem ..."
& gem install serverspec --version 2.7.0 --no-document --conservative --minimal-deps --verbose

Write-Output "Installing the RSpec JUnit formatter ..."
& gem install rspec_junit_formatter --version 0.2.0 --no-document --conservative --minimal-deps --verbose

Write-Output "Executing ServerSpec tests ..."
& rspec --format RspecJunitFormatter --out "$logDirectory\serverspec.xml" --pattern "$testDirectory/spec/*/*_spec.rb"

return $LastExitCode

<#

$dir = "c:\temp"
if (-not (Test-Path $dir))
{
    $result.HasPassed = $false
    $error = New-Error "The temp directory was not created"
    $result.Log += $error
    return $result
}

$log = New-Information "The temp directory was created successfully"
$result.Log += $log

$file = Join-Path $dir "myfile.txt"
if (-not (Test-Path $file))
{
    $result.HasPassed = $false
    $error = New-Error "The test file was not created"
    $result.Log += $error
    return $result
}

$log = New-Information "The test file was created successfully"
$result.Log += $log

$content = Get-Content -Path $file
if ($content -ne "This is a test")
{
    $result.HasPassed = $false
    $error = New-Error "The test file contained the wrong content. Expected 'This is a test' but got: $content"
    $result.Log += $error
    return $result
}

$log = New-Information "The test file contained the correct content"
$result.Log += $log
$result
#>
