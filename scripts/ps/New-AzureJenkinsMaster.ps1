[CmdletBinding(SupportsShouldProcess = $True)]
param(
    [string] $configFile = $(throw "Please provide a configuration file path.")
)

# Stop everything if there are errors
$ErrorActionPreference = 'Stop'

# Load the helper functions
$azureHelpers = Join-Path $PSScriptRoot AzureJenkinsHelpers.ps1
. $azureHelpers

if (-not (Test-Path $configFile))
{
    throw "File not found. Configuration file path is invalid: $configFile"
}

# Get the data from the configuration file
# XML file is expected to look like:
# <?xml version="1.0" encoding="utf-8"?>
# <configuration>
#     <authentication>
#         <certificate name="${CertificateName}" />
#     </authentication>
#     <cloudservice name="${ServiceName}" location="${ServiceLocation}" affinity="${ServiceAffinity}">
#         <domain name="${DomainName}" organizationalunit="${DomainOrganizationalUnit}">
#             <admin domainname="${DomainNameForAdmin}" name="${AdminUserName}" password="${AdminPassword}" />
#         </domain>
#         <image name="${ImageName}" label="${ImageLabel}">
#             <baseimage>${BaseImageName}</baseimage>
#         </machine>
#     </cloudservice>
#     <desiredstate>
#         <installerpath>${DirectoryWithInstallers}</installerpath>
#         <entrypoint name="${InstallerMainScriptName}" />
#     </desiredstate>
# </configuration>
$config = ([xml](Get-Content $configFile)).configuration

$certificateSubject = $config.authentication.certificate.name
Write-Verbose "certificateSubject: $certificateSubject"

$baseImage = $config.cloudservice.image.baseimage
Write-Verbose "baseImage: $baseImage"

$domainName = $config.cloudservice.domain.name
Write-Verbose "domainName: $domainName"

$adminDomainName = $config.cloudservice.domain.admin.domainname
Write-Verbose "adminDomainName: $adminDomainName"

$domainAdmin = $config.cloudservice.domain.admin.name
Write-Verbose "domainAdmin: $domainAdmin"

$domainPassword = $config.cloudservice.domain.admin.password

$storageAccount = $config.cloudservice.image.storageaccount
Write-Verbose "storageAccount: $storageAccount"

$cloudSvcName = $config.cloudservice.name
Write-Verbose "cloudSvcName: $cloudSvcName"

$installationDirectory = $config.desiredstate.installerpath
Write-Verbose "installationDirectory: $installationDirectory"

$installationScript = $config.desiredstate.entrypoint.name
Write-Verbose "installationScript: $installationScript"

$imageName = $config.cloudservice.image.name
Write-Verbose "imageName: $imageName"

$imageLabel = $config.cloudservice.image.label
Write-Verbose "imageLabel: $imageLabel"

# Get the certificate from the local user cert store
# cert can be made like this: http://blogs.msdn.com/b/cclayton/archive/2012/03/21/windows-azure-and-x509-certificates.aspx
$certificate = Get-ChildItem -Path Cert:\CurrentUser\My | Where-Object { $_.Subject -match $certificateSubject } | Select-Object -First 1
if (($certificate -eq $null) -or ($certificate -eq ''))
{
    throw "Unable to find the certificate with subject: $certificateSubject"
}

# The name of the VM is technically irrevant because we're only after the disk in the end. So make sure it's unique but don't bother 
# with an actual name
$vmName = [System.Guid]::NewGuid().ToString()
Write-Verbose "vmName: $vmName"

# For the timezone use the timezone of the current machine
$timeZone = [System.TimeZoneInfo]::Local.StandardName
Write-Verbose ("timeZone: " + $timeZone)

# The media location is the name of the storage account appropriately mangled into a URL
$mediaLocation = ("https://" + $storageAccount + ".blob.core.windows.net/vhds/" + $vmname + ".vhd")

# Create a machine. This machine isn't actually going to be used for anything other than installing the software so it doesn't need to
# be big (hence using the InstanceSize Basic_A0).
Write-Output "Creating temporary virtual machine for $cloudSvcName in $location based on $baseImage"
$vmConfig = New-AzureVMConfig -Name $vmName -InstanceSize Basic_A0 -ImageName $baseImage -MediaLocation $mediaLocation

Write-Verbose "Stuff"
$vmConfig | Add-AzureProvisioningConfig `
        -WindowsDomain `
        -TimeZone $timeZone `
        -DisableAutomaticUpdates `
        -WinRMCertificate $certificate `
        -NoRDPEndpoint `
        -AdminUserName 'admin' `
        -JoinDomain $domainName `
        -Domain $domainName `
        -DomainUserName $domainAdmin `
        -DomainPassword $domainPassword

# attach smaller disk
# attach to network

# Create the machine and start it
New-AzureVM -ServiceName $cloudSvcName -VMs $vmConfig -WaitForBoot -Verbose -ErrorAction Stop

# Get the remote endpoint
$uri = Get-AzureWinRMUri -ServiceName $cloudSvcName -Name $vmName -ErrorAction Stop

# create the credential
$securePassword = ConvertTo-SecureString $domainPassword -AsPlainText -Force
$credential = New-Object pscredential($domainAdmin, $securePassword)

# Connect through WinRM
$session = New-PSSession -ConnectionUri $uri -Credential $credential -ErrorAction Stop

# Push binaries to the new VM
$remoteDirectory = 'c:\temp'
$filesToCopy = Get-ChildItem -Path $installationDirectory -Verbose
foreach($fileToCopy in $filesToCopy)
{
    $remotePath = Join-Path $remoteDirectory (Split-Path -Leaf $fileToCopy)
    Copy-ItemToRemoteMachine -localPath $fileToCopy -remotePath $remotePath -Session $session -Verbose
}

# Execute the remote installation scripts
Invoke-Command `
    -Session $session `
    -ArgumentList @( (Join-Path $remoteDirectory (Split-Path -Leaf $installationScript)) ) `
    -ScriptBlock {
        param(
            [string] $installationScript
        )
        
        & $installationScript
    } `
     -ErrorAction Stop

<#
# Sysprep
# Note that apparently this can't be done just remotely because sysprep starts but doesn't actually
# run (i.e. it exits without doing any work). So this needs to be done from the local machine 
# that is about to be sysprepped.
Invoke-Command `
    -Session $session `
    -ArgumentList @( (Join-Path $remoteDirectory 'sysprep.bat') ) `
    -ScriptBlock {
        param(
            [string] $sysPrepScript
        )

        & $sysPrepScript
    } `
     -ErrorAction Stop

# Wait for machine to turn off. Wait for a maximum of 5 minutes before we fail it.
$isRunning = $true
$timeout = [System.TimeSpan]::FromMinutes(5)
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

# templatize
Save-AzureVMImage -ServiceName $cloudSvcName -Name $vmName -ImageName $imageName -OSState Generalized -ImageLabel $imageLabel  -ErrorAction Stop
#>