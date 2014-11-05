<#
    .SYNOPSIS
 
    Executes the tests that verify whether the current machine has all the tools installed to allow it to work as a Windows Jenkins master.
 
 
    .DESCRIPTION
 
    The Test-AzureJenkinsMaster script executes the tests that verify whether the current machine has all the tools installed to allow it to work as a Windows Jenkins master.
 
 
    .EXAMPLE
 
    Test-AzureJenkinsMaster
#>
[CmdletBinding()]
param()

<#
    
#>
function New-Error{
    param(
        [string] $errorText
    )

    $time = [System.DateTimeOffset]::Now.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")

    $errorResult = New-Object PSObject
    Add-Member -InputObject $errorResult -MemberType NoteProperty -Name Message -Value $errorText
    Add-Member -InputObject $errorResult -MemberType NoteProperty -Name MessageType -Value "Error"
    Add-Member -InputObject $errorResult -MemberType NoteProperty -Name DateTime -Value $time
    
    $errorResult
}

<#

#>
function New-Information{
    param(
        [string] $infoText
    )

    $time = [System.DateTimeOffset]::Now.ToString("yyyy-MM-ddTHH:mm:ss.fffzzz")

    $infoResult = New-Object PSObject
    Add-Member -InputObject $infoResult -MemberType NoteProperty -Name Message -Value $infoText
    Add-Member -InputObject $infoResult -MemberType NoteProperty -Name MessageType -Value "Info"
    Add-Member -InputObject $infoResult -MemberType NoteProperty -Name DateTime -Value $time
    
    $infoResult
}

try
{
    $result = New-Object PSObject
    Add-Member -InputObject $result -MemberType NoteProperty -Name HasPassed -Value $true
    Add-Member -InputObject $result -MemberType NoteProperty -Name Log -Value @( )

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
}
catch
{
    $result = New-Object PSObject
    $result = Add-Member -InputObject $result -MemberType NoteProperty -Name HasPassed -Value $true

    $error = New-Error "Script failed with error: $_"
    $result = Add-Member -InputObject $result -MemberType NoteProperty -Name Log -Value @( $error )

    return $result
}