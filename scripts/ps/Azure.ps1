function Copy-ItemToRemoteMachine
{
    [CmdletBinding()]
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

function New-AzureVMFromTemplate
{
    [CmdletBinding()]
    param(
        [string] $resourceGroupName,
        [string] $storageAccount,
        [string] $baseImage,
        [string] $vmName,
        [string] $sslCertificateName,
        [string] $adminName,
        [string] $adminPassword
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # For the timezone use the timezone of the current machine
    $timeZone = [System.TimeZoneInfo]::Local.StandardName
    Write-Verbose ("timeZone: " + $timeZone)

    # The media location is the name of the storage account appropriately mangled into a URL
    $mediaLocation = ("https://" + $storageAccount + ".blob.core.windows.net/vhds/" + $vmname + ".vhd")

    # Create a machine. This machine isn't actually going to be used for anything other than installing the software so it doesn't need to
    # be big (hence using the InstanceSize Basic_A0).
    Write-Output "Creating temporary virtual machine for $resourceGroupName in $mediaLocation based on $baseImage"
    $vmConfig = New-AzureVMConfig -Name $vmName -InstanceSize Basic_A0 -ImageName $baseImage -MediaLocation $mediaLocation @commonParameterSwitches

    $certificate = Get-ChildItem -Path Cert:\CurrentUser\Root | Where-Object { $_.Subject -match $sslCertificateName } | Select-Object -First 1
    $vmConfig | Add-AzureProvisioningConfig `
            -Windows `
            -TimeZone $timeZone `
            -DisableAutomaticUpdates `
            -WinRMCertificate $certificate `
            -NoRDPEndpoint `
            -AdminUserName $adminName `
            -Password $adminPassword `
            @commonParameterSwitches

    # Create the machine and start it
    New-AzureVM -ServiceName $resourceGroupName -VMs $vmConfig -WaitForBoot @commonParameterSwitches
}

function Get-PSSessionForAzureVM
{
    [CmdletBinding()]
    param(
        [string] $resourceGroupName,
        [string] $vmName,
        [string] $adminName,
        [string] $adminPassword
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Get the remote endpoint
    $uri = Get-AzureWinRMUri -ServiceName $resourceGroupName -Name $vmName @commonParameterSwitches

    # create the credential
    $securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force @commonParameterSwitches
    $credential = New-Object pscredential($adminName, $securePassword)

    # Connect through WinRM
    $session = New-PSSession -ConnectionUri $uri -Credential $credential @commonParameterSwitches

    return $session
}

function Add-AzureFilesToVM
{
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $remoteDirectory = "c:\installers",
        [string[]] $filesToCopy
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Create the installer directory on the virtual machine
    Invoke-Command `
        -Session $session `
        -ArgumentList @( $remoteDirectory ) `
        -ScriptBlock {
            param(
                [string] $dir
            )
        
            New-Item -Path $dir -ItemType Directory
        } `
         @commonParameterSwitches

    # Push binaries to the new VM
    Write-Verbose "Copying files to virtual machine: $filesToCopy"
    foreach($fileToCopy in $filesToCopy)
    {
        $remotePath = Join-Path $remoteDirectory (Split-Path -Leaf $fileToCopy)

        Write-Verbose "Copying $fileToCopy to $remotePath"
        Copy-ItemToRemoteMachine -localPath $fileToCopy -remotePath $remotePath -Session $session @commonParameterSwitches
    }
}

function New-AzureSyspreppedVMImage
{
    [CmdletBinding()]
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $resourceGroupName,
        [string] $vmName,
        [string] $imageName,
        [string] $imageLabel
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    $cmd = 'c:\Windows\system32\sysprep\sysprep.exe /oobe /generalize /shutdown'
    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    $sysprepCmd = Join-Path $tempDir 'sysprep.cmd'
    
    $remoteDirectory = "c:\sysprep"
    try
    {
        if (-not (Test-Path $tempDir))
        {
            New-Item -Path $tempDir -ItemType Directory | Out-Null
        }
        
        Set-Content -Value $cmd -Path $sysprepCmd
        Add-AzureFilesToVM -session $session -remoteDirectory $remoteDirectory -filesToCopy @( $sysprepCmd )
    }
    finally
    {
        Remove-Item -Path $tempDir -Force -Recurse
    }
    
    # Sysprep
    # Note that apparently this can't be done just remotely because sysprep starts but doesn't actually
    # run (i.e. it exits without doing any work). So this needs to be done from the local machine 
    # that is about to be sysprepped.
    Invoke-Command `
        -Session $session `
        -ArgumentList @( (Join-Path $remoteDirectory (Split-Path -Leaf $sysprepCmd)) ) `
        -ScriptBlock {
            param(
                [string] $sysPrepScript
            )

            & $sysPrepScript
        } `
         @commonParameterSwitches

    # Wait for machine to turn off. Wait for a maximum of 5 minutes before we fail it.
    $isRunning = $true
    $timeout = [System.TimeSpan]::FromMinutes(10)
    $killTime = [System.DateTimeOffset]::Now + $timeout
    while ($isRunning)
    {
        $vm = Get-AzureVM -Name $vmName
        if ($vm.Status -eq "StoppedDeallocated")
        {
            $isRunning = $false
        }

        if ([System.DateTimeOffset]::Now -gt $killTime)
        {
            $isRunning = false;
            throw "Virtual machine Sysprep failed to complete within $timeout"
        }
    }

    Save-AzureVMImage -ServiceName $resourceGroupName -Name $vmName -ImageName $imageName -OSState Generalized -ImageLabel $imageLabel  @commonParameterSwitches
}