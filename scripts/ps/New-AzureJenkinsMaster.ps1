[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [string] $configFile = $(throw "Please provide a configuration file path.")
)

$scriptPath = $PSScriptRoot

# Get the certificate from the local user cert store
# cert can be made like this: http://blogs.msdn.com/b/cclayton/archive/2012/03/21/windows-azure-and-x509-certificates.aspx
$certificate = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -match $certificateSubject } | Select-Object -First 1

# Create machine
$vmConfig = New-AzureVMConfig -Name $vmName -InstanceSize ExtraSmall -ImageName $image |
    Add-AzureProvisioningConfig `
        -Windows `
        -TimeZone $timeZone `
        -JoinDomain $domain `
        -Domain $domain `
        -DomainUserName $domainAdmin `
        -DomainPassword $domainPassword `
        -MachineObjectOU $machineObjectOU `
        -DisableAutomaticUpdates `
        -WinRMCertificate $certificate `
        -NoRDPEndpoint

# Create the machine and start it
New-AzureVM -ServiceName $cloudSvcName -Location $location -AffinityGroup $affinityGroup -VMs $vmConfig -WaitForBoot

# Get the remote endpoint
$uri = Get-AzureWinRMUri -ServiceName $cloudSvcName -Name $vmName

# create the credential
$securePassword = ConvertTo-SecureString $domainPassword -AsPlainText -Force
$credential = New-Object pscredential($domainAdmin, $securePassword)

# Connect through WinRM
$session = New-PSSession -ConnectionUri $uri -Credential $credential

# Push binaries
$remoteCopy = Join-Path $scriptPath Copy-ItemToRemoteMachine.ps1

foreach($fileToCopy in $filesToCopy)
{
    $remotePath = Join-Path $remoteDirectory [System.IO.Path]::GetFileName($fileToCopy)
    Write-Verbose "Copying $fileToCopy to remote machine at $remotePath"
    & $remoteCopy -localPath $fileToCopy -remotePath $remotePath -Session $session -Verbose
}

# connect to share drive

# Execute the remote installation scripts
Invoke-Command `
    -Session $session `
    -ArgumentList @() `
    -ScriptBlock {
        param(
            [string] $installationScript
        )
        
        & $installationScript
    } 

# Sysprep
# Note that apparently this can't be done just remotely. It needs to be done from the machine
Invoke-Command `
    -Session $session `
    -ArgumentList @( (Join-Path $remoteDirectory 'sysprep.bat') ) `
    -ScriptBlock {
        param(
            [string] $sysPrepScript
        )

        & $sysPrepScript
    }

# Wait for machine to turn off

# templatize
Save-AzureVMImage -ServiceName $cloudSvcName -Name $name -ImageName $imageName -OSState Generalized -ImageLabel $label