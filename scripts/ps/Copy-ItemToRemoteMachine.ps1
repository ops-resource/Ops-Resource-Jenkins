# http://measureofchaos.wordpress.com/2012/09/26/copying-files-via-powershell-remoting-channel/
[CmdletBinding()]]
param(
    [string] $localPath,
    [string] $remotePath,
    [System.Management.Automation.Runspaces.PSSession] $session
)

# Use .NET file handling for speed
$content = [Io.File]::ReadAllBytes( $localPath )
$contentsizeMB = $content.Count / 1MB + 1MB

Write-Output "Copying $fileName from $localPath to $remotePath on $Connection.Name ..."

# Open local file
try
{
    [IO.FileStream]$filestream = [IO.File]::OpenRead( $localPath )
    Write-Output "Opened local file for reading"
}
catch
{
    Write-Error "Could not open local file $localPath because:" $_.Exception.ToString()
    Return $false
}

# Open remote file
try
{
    Invoke-Command -Session $Session -ScriptBlock {
        Param($remFile)
        [IO.FileStream]$filestream = [IO.File]::OpenWrite( $remFile )
    } -ArgumentList $remotePath
    Write-Output "Opened remote file for writing"
}
catch
{
    Write-Error "Could not open remote file $remotePath because:" $_.Exception.ToString()
    Return $false
}

# Copy file in chunks
$chunksize = 1MB
[byte[]]$contentchunk = New-Object byte[] $chunksize
$bytesread = 0
while (($bytesread = $filestream.Read( $contentchunk, 0, $chunksize )) -ne 0)
{
    try
    {
        $percent = $filestream.Position / $filestream.Length
        Write-Output ("Copying {0}, {1:P2} complete, sending {2} bytes" -f $fileName, $percent, $bytesread)
        Invoke-Command -Session $Session -ScriptBlock {
            Param($data, $bytes)
            $filestream.Write( $data, 0, $bytes )
        } -ArgumentList $contentchunk,$bytesread
    }
    catch
    {
        Write-Error "Could not copy $fileName to $($Connection.Name) because:" $_.Exception.ToString()
        return $false
    }
    finally
    {
    }
}

# Close remote file
try
{
    Invoke-Command -Session $Session -ScriptBlock {
        $filestream.Close()
    }
    Write-Output "Closed remote file, copy complete"
}
catch
{
    Write-Error "Could not close remote file $remotePath because:" $_.Exception.ToString()
    Return $false
}

# Close local file
try
{
    $filestream.Close()
    Write-Output "Closed local file, copy complete"
}
catch
{
    Write-Error "Could not close local file $localPath because:" $_.Exception.ToString()
    Return $false
}