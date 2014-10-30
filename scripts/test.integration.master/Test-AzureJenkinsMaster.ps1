[CmdletBinding()]
param()

function New-Error{
    param(
        [string] $errorText
    )

    $errorResult = New-Object PSObject
    $errorResult = Add-Member -InputObject $errorResult -MemberType NoteProperty -Name Message -Value $errorText
    $errorResult = Add-Member -InputObject $errorResult -MemberType ScriptMethod -Name Write -Value { Write-Error $this.Message }
    
    $errorResult
}

function New-Information{
    param(
        [string] $infoText
    )

    $infoResult = New-Object PSObject
    $infoResult = Add-Member -InputObject $infoResult -MemberType NoteProperty -Name Message -Value $infoText
    $infoResult = Add-Member -InputObject $infoResult -MemberType ScriptMethod -Name Write -Value { Write-Output $this.Message }
    
    $infoResult
}

$result = New-Object PSObject
$result = Add-Member -InputObject $result -MemberType NoteProperty -Name HasPassed -Value $true
$result = Add-Member -InputObject $result -MemberType NoteProperty -Name Log -Value @( )

$dir = "c:\temp"
if (-not (Test-Path $dir))
{
    $result.HasPassed = $false
    $result.Log += New-Error "The temp directory was not created"
    return $result
}

$result.Log += New-Information "The temp directory was created successfully"

$file = Join-Path $dir "myfile.txt"
if (-not (Test-Path $file))
{
    $result.HasPassed = $false
    $result.Log += New-Error "The test file was not created"
    return $result
}

$result.Log += New-Information "The test file was created successfully"

$content = Get-Content -Path $file
if ($content -ne "This is a test")
{
    $result.HasPassed = $false
    $result.Log += New-Error "The test file contained the wrong content. Expected 'This is a test' but got: $content"
    return $result
}

$result.Log += New-Information "The test file contained the correct content"
$result