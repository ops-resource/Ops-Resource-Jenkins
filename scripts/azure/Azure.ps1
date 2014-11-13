<#
    .SYNOPSIS
 
    Copies a file to the given remote path on the machine that the session is connected to.
 
 
    .DESCRIPTION
 
    The Copy-ItemToRemoteMachine function copies a local file to the given remote path on the machine that the session is connected to.
 
 
    .PARAMETER localPath
 
    The full path of the file that should be copied.
 
 
    .PARAMETER remotePath
 
    The full file path to which the local file should be copied
 
 
    .PARAMETER session
 
    The PSSession that provides the connection between the local machine and the remote machine.
 
 
    .EXAMPLE
 
    Copy-ItemToRemoteMachine -localPath 'c:\temp\myfile.txt' -remotePath 'c:\remote\myfile.txt' -session $session
#>
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

    Write-Output "Copying $fileName from $localPath to $remotePath on $session.Name ..."

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

function Read-FromRemoteStream
{
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [int] $chunkSize
    )

    try 
    {
        $data = Invoke-Command `
            -Session $Session `
            -ScriptBlock {
                Param(
                    $size
                )

                [byte[]]$contentchunk = New-Object byte[] $size
                $bytesread = $filestream.Read( $contentchunk, 0, $size ))

                $result = New-Object PSObject
                Add-Member -InputObject $result -MemberType NoteProperty -Name BytesRead -Value $BytesRead
                Add-Member -InputObject $result -MemberType NoteProperty -Name Chunk -Value $contentchunk

                return result
            } `
            -ArgumentList $chunkSize

        return $data
    }
    catch 
    {
        Write-Error "Could not copy $fileName to $($Connection.Name) because:" $_.Exception.ToString()
        return -1
    }
    finally
    {

    }
}

<#
    .SYNOPSIS
 
    Copies a file from the given remote path on the machine that the session is connected to.
 
 
    .DESCRIPTION
 
    The Copy-ItemFromRemoteMachine function copies a remote file to the given local path on the machine that the session is connected to.
 
 
    .PARAMETER remotePath
 
    The full file path from which the local file should be copied


    .PARAMETER localPath
 
    The full path of the file to which the file should be copied.

  
    .PARAMETER session
 
    The PSSession that provides the connection between the local machine and the remote machine.
 
 
    .EXAMPLE
 
    Copy-ItemFromRemoteMachine -remotePath 'c:\remote\myfile.txt' -localPath 'c:\temp\myfile.txt' -session $session
#>
function Copy-ItemFromRemoteMachine
{
    [CmdletBinding()]
    param(
        [string] $remotePath,
        [string] $localPath,
        [System.Management.Automation.Runspaces.PSSession] $session
    )

    # Use .NET file handling for speed
    $content = [Io.File]::ReadAllBytes( $localPath )
    $contentsizeMB = $content.Count / 1MB + 1MB

    Write-Output "Copying $fileName from $localPath to $remotePath on $session.Name ..."

    # Open local file
    try
    {
        [IO.FileStream]$filestream = [IO.File]::OpenWrite( $localPath )
        Write-Output "Opened local file for writing"
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
            [IO.FileStream]$filestream = [IO.File]::OpenRead( $remFile )
        } -ArgumentList $remotePath
        Write-Output "Opened remote file for reading"
    }
    catch
    {
        Write-Error "Could not open remote file $remotePath because:" $_.Exception.ToString()
        Return $false
    }

    # Copy file in chunks
    $chunksize = 1MB
    $data = $null
    while (($data = Read-FromRemoteStream $session $chunksize ).BytesRead -ne 0)
    {
        try
        {
            $percent = $filestream.Position / $filestream.Length
            Write-Output ("Copying {0}, {1:P2} complete, receiving {2} bytes" -f $fileName, $percent, $bytesread)
            $fileStream.Write( $data.Chunk, 0, $data.BytesRead)
        }
        catch
        {
            Write-Error "Could not copy $fileName from $($Connection.Name) because:" $_.Exception.ToString()
            return $false
        }
        finally
        {
        }
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
}

<#
    .SYNOPSIS
 
    Creates a new Azure VM from a given base image in the given resource group.
 
 
    .DESCRIPTION
 
    The New-AzureVMFromTemplate function creates a new Azure VM in the given resources group. The VM will be based on 
    the provided image.
 
 
    .PARAMETER resourceGroupName
 
    The name of the resource group in which the VM should be created.
 
 
    .PARAMETER storageAccount
 
    The name of the storage account in which the VM should be created. This storage account should be linked to the given
    resource group.
 
 
    .PARAMETER baseImage
 
    The full name of the image that the VM should be based on.
 
 
    .PARAMETER vmName
 
    The azure name of the VM. This will also be the computer name. May contain a maximum of 15 characters.


    .PARAMETER sslCertificateName
 
    The subject name of the SSL certificate in the user root store that can be used for WinRM communication with the VM. The certificate
    should have an exportable private key. Note that the certificate name has to match the public name of the machine, most likely 
    $resourceName.cloudapp.net. Defaults to '$resourceGroupName.cloudapp.net'


    .PARAMETER adminName
 
    The name for the administrator account. Defaults to 'TheBigCheese'.


    .PARAMETER adminPassWord
 
    The password for the administrator account.
 
 
    .EXAMPLE
 
    New-AzureVMFromTemplate 
        -resourceGroupName 'jenkinsresource'
        -storageAccount 'jenkinsstorage'
        -baseImage 'a699494373c04fc0bc8f2bb1389d6106__Windows-Server-2012-R2-201409.01-en.us-127GB.vhd'
        -vmName 'ajm-305-220615'
        -sslCertificateName 'jenkinsresource.cloudapp.net'
        -adminName 'TheOneInCharge'
        -adminPassword 'PeanutsOrMaybeNot'
#>
function New-AzureVMFromTemplate
{
    [CmdletBinding()]
    param(
        [string] $resourceGroupName,
        [string] $storageAccount,
        [string] $baseImage,
        [string] $vmName,
        [string] $sslCertificateName = "$resourceGroupName.cloudapp.net",
        [string] $adminName = 'TheBigCheese',
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

<#
    .SYNOPSIS
 
    Gets a PSSession that can be used to connect to the remote virtual machine.
 
 
    .DESCRIPTION
 
    The Get-PSSessionForAzureVM function returns a PSSession that can be used to use Powershell remoting to connect to the virtual
    machine with the given name.
 
 
    .PARAMETER resourceGroupName
 
    The name of the resource group in which the VM exists.
 
 
    .PARAMETER vmName
 
    The azure name of the VM.
 
 
    .PARAMETER adminName
 
    The name for the administrator account.
 
 
    .PARAMETER adminPassword
 
    sThe password for the administrator account.
 

    .OUTPUTS

    Returns the PSSession for the connection to the VM with the given name.

 
    .EXAMPLE
 
    Get-PSSessionForAzureVM
        -resourceGroupName 'jenkinsresource'
        -vmName 'ajm-305-220615'
        -adminName 'TheOneInCharge'
        -adminPassword 'PeanutsOrMaybeNot'
#>
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

<#
    .SYNOPSIS
 
    Copies a set of files to a remote directory on a given Azure VM.
 
 
    .DESCRIPTION
 
    The Copy-AzureFilesToVM function copies a set of files to a remote directory on a given Azure VM.
 
 
    .PARAMETER session
 
    The PSSession that provides the connection between the local machine and the remote machine.
 
 
    .PARAMETER remoteDirectory
 
    The full path to the remote directory into which the files should be copied. Defaults to 'c:\installers'
 
 
    .PARAMETER filesToCopy
 
    The collection of local files that should be copied.
 
 
    .EXAMPLE
 
    Copy-AzureFilesToVM -session $session -remoteDirectory 'c:\temp' -filesToCopy (Get-ChildItem c:\temp -recurse)
#>
function Copy-AzureFilesToVM
{
    [CmdletBinding()]
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
        
            if (-not (Test-Path $dir))
            {
                New-Item -Path $dir -ItemType Directory
            }
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

<#
    .SYNOPSIS
 
    Copies a set of files from a remote directory on a given Azure VM.
 
 
    .DESCRIPTION
 
    The Copy-AzureFilesFromVM function copies a set of files from a remote directory on a given Azure VM.
 
 
    .PARAMETER session
 
    The PSSession that provides the connection between the local machine and the remote machine.
 
 
    .PARAMETER remoteDirectory
 
    The full path to the remote directory from which the files should be copied. Defaults to 'c:\logs'
 
 
    .PARAMETER localDirectory
 
    The full path to the local directory into which the files should be copied.
 
 
    .EXAMPLE
 
    Copy-AzureFilesToVM -session $session -remoteDirectory 'c:\temp' -localDirectory 'c:\temp'
#>
function Copy-AzureFilesFromVM
{
    [CmdletBinding()]
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $remoteDirectory = "c:\logs",
        [string] $localDirectory
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    # Create the directory on the local machine
    if (-not (Test-Path $localDirectory))
    {
        New-Item -Path $localDirectory -ItemType Directory
    }

    # Create the installer directory on the virtual machine
    $remoteFiles = Invoke-Command `
        -Session $session `
        -ArgumentList @( $remoteDirectory ) `
        -ScriptBlock {
            param(
                [string] $dir
            )
        
            return Get-ChildItem -Recurse -Path $dir
        } `
         @commonParameterSwitches

    # Push binaries to the new VM
    Write-Verbose "Copying files from the virtual machine"
    foreach($fileToCopy in $remoteFiles)
    {
        $file = $fileToCopy.FullName
        $localPath = Join-Path $localDirectory (Split-Path -Leaf $file)

        Write-Verbose "Copying $fileToCopy to $remotePath"
        Copy-ItemFromRemoteMachine -localPath $localPath -remotePath $file -Session $session @commonParameterSwitches
    }
}

<#
    .SYNOPSIS
 
    Removes a directory on the given Azure VM.
 
 
    .DESCRIPTION
 
    The Remove-AzureFilesFromVM function removes a directory on the given Azure VM.
 
 
    .PARAMETER session
 
    The PSSession that provides the connection between the local machine and the remote machine.
 
 
    .PARAMETER remoteDirectory
 
    The full path to the remote directory that should be removed
 
 
    .EXAMPLE
 
    Remove-AzureFilesFromVM -session $session -remoteDirectory 'c:\temp'
#>
function Remove-AzureFilesFromVM
{
    [CmdletBinding()]
    param(
        [System.Management.Automation.Runspaces.PSSession] $session,
        [string] $remoteDirectory = "c:\logs",
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
        
            if (Test-Path $dir)
            {
                Remove-Item -Path $dir -Force -Recurse
            }
        } `
         @commonParameterSwitches
}

<#
    .SYNOPSIS
 
    Syspreps an Azure VM and then creates an image from it.
 
 
    .DESCRIPTION
 
    The New-AzureSyspreppedVMImage function executes sysprep on a given Azure VM and then once the VM is shut down creates an image from it.
 
 
    .PARAMETER session
 
    The PSSession that provides the connection between the local machine and the remote machine.
 
 
    .PARAMETER resourceGroupName
 
    The name of the resource group in which the VM exists.
 
 
    .PARAMETER vmName
 
    The azure name of the VM.
 
 
    .PARAMETER imageName
 
    The name of the image.


    .PARAMETER imageLabel
 
    The label of the image.
 
 
    .EXAMPLE
 
    New-AzureSyspreppedVMImage
        -session $session
        -resourceGroupName 'jenkinsresource'
        -vmName 'ajm-305-220615'
        -imageName "jenkins-master-win2012R2_0.2.0"
        -imageLabel "Jenkins master on Windows Server 2012 R2"
#>
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

    $cmd = 'Write-Output "Executing $sysPrepScript on VM"; & c:\Windows\system32\sysprep\sysprep.exe /oobe /generalize /shutdown'
    $tempDir = Join-Path $env:TEMP ([System.Guid]::NewGuid().ToString())
    $sysprepCmd = Join-Path $tempDir 'sysprep.ps1'
    
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
    Write-Verbose "Starting sysprep ..."
    Invoke-Command `
        -Session $session `
        -ArgumentList @( (Join-Path $remoteDirectory (Split-Path -Leaf $sysprepCmd)) ) `
        -ScriptBlock {
            param(
                [string] $sysPrepScript
            )

            & "$sysPrepScript"
        } `
         -Verbose `
         -ErrorAction Continue

    # Wait for machine to turn off. Wait for a maximum of 5 minutes before we fail it.
    $isRunning = $true
    $timeout = [System.TimeSpan]::FromMinutes(20)
    $killTime = [System.DateTimeOffset]::Now + $timeout
    $hasFailed = $false
    
    Write-Verbose "SysPrep is shutting down machine. Waiting ..."
    try
    {
        while ($isRunning)
        {
            $vm = Get-AzureVM -ServiceName $resourceGroupName -Name $vmName
            Write-Verbose ("$vmName is status: " + $vm.Status)
            
            if (($vm.Status -eq "StoppedDeallocated") -or ($vm.Status -eq "StoppedVM"))
            {
                Write-Verbose "VM stopped"
                $isRunning = $false
            }

            if ([System.DateTimeOffset]::Now -gt $killTime)
            {
                Write-Verbose "VM failed to stop within time-out"
                $isRunning = false;
                $hasFailed = $true
            }
        }
    }
    catch
    {
        Write-Verbose "Failed during time-out loop"
        # failed. Just ignore it
    }

    if ($hasFailed)
    {
        throw "Virtual machine Sysprep failed to complete within $timeout"
    }

    Write-Verbose "Sysprep complete. Starting image creation"

    Write-Verbose "ServiceName: $resourceGroupName"
    Write-Verbose "Name: $vmName"
    Write-Verbose "ImageName: $imageName"
    Write-Verbose "ImageLabel: $imageLabel"
    Save-AzureVMImage -ServiceName $resourceGroupName -Name $vmName -ImageName $imageName -OSState Generalized -ImageLabel $imageLabel  @commonParameterSwitches
}

<#
    .SYNOPSIS
 
    Removes a VM image from the user library.
 
 
    .DESCRIPTION
 
    The Remove-AzureSyspreppedVMImage function removes a VM image from the user library.
 
 
    .PARAMETER imageName
 
    The name of the image.
 
 
    .EXAMPLE
 
    Remove-AzureSyspreppedVMImage -imageName "jenkins-master-win2012R2_0.2.0"
#>
function Remove-AzureSyspreppedVMImage
{
    [CmdletBinding()]
    param(
        [string] $imageName
    )

    # Stop everything if there are errors
    $ErrorActionPreference = 'Stop'

    $commonParameterSwitches =
        @{
            Verbose = $PSBoundParameters.ContainsKey('Verbose');
            Debug = $PSBoundParameters.ContainsKey('Debug');
            ErrorAction = "Stop"
        }

    Remove-AzureVMImage -ImageName $imageName -DeleteVHD @commonParameterSwitches
}