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