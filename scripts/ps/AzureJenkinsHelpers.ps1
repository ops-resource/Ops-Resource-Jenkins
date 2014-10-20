function New-AzureServiceName
{
    param(
        $maximumNumberOfRetries = 10    
    )

    $nameExists = $true
    $count = 0
    while ($nameExists -and ($count -le $maximumNumberOfRetries))
    {
        $cloudSvcName = [System.Guid]::NewGuid().ToString()
        $nameExists = Test-AzureName $cloudSvcName
        $count++
    }

    if ($nameExists -and ($count -ge $maximumNumberOfRetries))
    {
        throw "Failed to generate a suitable Azure service name."
    }

    return $cloudSvcName
}

function Copy-ItemToRemoteMachine
{
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
}

<#
    .SYNOPSIS

    Downloads and installs the certificate created or initially uploaded during creation of a Windows based Windows Azure Virtual Machine.


    .DESCRIPTION

    Downloads and installs the certificate created or initially uploaded during creation of a Windows based Windows Azure Virtual Machine.
    Running this script installs the downloaded certificate into your local machine certificate store (why it requires PowerShell to run elevated). 
    This allows you to connect to remote machines without disabling SSL checks and increasing your security. 


    .PARAMETER SubscriptionName

    The name of the subscription stored in WA PowerShell to use. Use quotes around subscription names with spaces. 
    Download and configure the Windows Azure PowerShell cmdlets first and use Get-AzureSubscription | Select SubscriptionName to identify the name.


    .PARAMETER ServiceName

    The name of the cloud service the virtual machine is deployed in.


    .PARAMETER Name

    The name of the virtual machine to install the certificate for. 

    .EXAMPLE

    .\InstallWinRMCertAzureVM.ps1 -SubscriptionName "my subscription" -ServiceName "mycloudservice" -Name "myvm1" 

#>
<#
    Original script from here: https://gallery.technet.microsoft.com/scriptcenter/Configures-Secure-Remote-b137f2fe
    Changes made to store the script in the local user cert store so that we don't need to run this as admin.
#>
Function InstallWinRMCertificateForVM()
{
    param(
        [string] $CloudServiceName, 
        [string] $Name
    )
	
    Write-Output "Installing WinRM Certificate for remote access: $CloudServiceName $Name"
	$WinRMCert = (Get-AzureVM -ServiceName $CloudServiceName -Name $Name | Select-Object -ExpandProperty vm).DefaultWinRMCertificateThumbprint
	$AzureX509cert = Get-AzureCertificate -ServiceName $CloudServiceName -Thumbprint $WinRMCert -ThumbprintAlgorithm sha1

	$certTempFile = [IO.Path]::GetTempFileName()
	$AzureX509cert.Data | Out-File $certTempFile

	# Target The Cert That Needs To Be Imported
	$CertToImport = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2 $certTempFile

	$store = New-Object System.Security.Cryptography.X509Certificates.X509Store "Root", "CurrentUser"
	$store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
	$store.Add($CertToImport)
	$store.Close()
	
	Remove-Item $certTempFile
}