[CmdletBinding()]
param()

$dir = "c:\temp"
if (-not (Test-Path $dir))
{
    New-Item -Path $dir -ItemType Directory
}

Set-Content -Value "This is a test" -Path (Join-Path $dir "myfile.txt")