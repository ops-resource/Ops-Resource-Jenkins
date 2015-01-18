#
# Cookbook Name:: master
# Recipe:: default
#
# Copyright 2014, Patrick van der Velde
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'windows'

configuration_directory = 'c:\\configuration'
log_directory = 'c:\\logs'

ci_directory = 'c:\\ci'
jenkins_java_file_name = 'jenkins.war'
service_name = 'jenkins'

# Create user
# - limited user (from AD?)
# - Reduce access to files. User should only have write access to Jenkins dir and workspaces
jenkins_username = 'jenkins_master'
jenkins_password = SecureRandom.uuid
user jenkins_username do
  password jenkins_password
  action :create
end

# Grant the user the LogOnAsService permission. Following this anwer on SO: http://stackoverflow.com/a/21235462/539846
# With some additional bug fixes to get the correct line from the export file and to put the correct text in the import file
powershell_script 'user_grant_service_logon_rights' do
  code <<-POWERSHELL
    $ErrorActionPreference = 'Stop'

    $userName = "#{jenkins_username}"
    $password = "#{jenkins_password}"

    $tempPath = "#{log_directory}"
    $import = Join-Path -Path $tempPath -ChildPath "import.inf"
    if(Test-Path $import)
    {
        Remove-Item -Path $import -Force
    }

    $export = Join-Path -Path $tempPath -ChildPath "export.inf"
    if(Test-Path $export)
    {
        Remove-Item -Path $export -Force
    }

    $secedt = Join-Path -Path $tempPath -ChildPath "secedt.sdb"
    if(Test-Path $secedt)
    {
        Remove-Item -Path $secedt -Force
    }

    Write-Host ("Granting SeServiceLogonRight to user account: {0} on host: {1}." -f $userName, $computerName)
    $sid = ((New-Object System.Security.Principal.NTAccount($userName)).Translate([System.Security.Principal.SecurityIdentifier])).Value

    secedit /export /cfg $export
    $line = (Select-String $export -Pattern "SeServiceLogonRight").Line
    $sids = $line.Substring($line.IndexOf('=') + 1).Trim()

    $lines = @(
            "[Unicode]",
            "Unicode=yes",
            "[System Access]",
            "[Event Audit]",
            "[Registry Values]",
            "[Version]",
            "signature=`"`$CHICAGO$`"",
            "Revision=1",
            "[Profile Description]",
            "Description=GrantLogOnAsAService security template",
            "[Privilege Rights]",
            "SeServiceLogonRight = $sids,*$sid"
        )
    foreach ($line in $lines)
    {
        Add-Content $import $line
    }

    secedit /import /db $secedt /cfg $import
    secedit /configure /db $secedt
    gpupdate /force
  POWERSHELL
end

# Install 7-zip
# options "INSTALLDIR=\"#{ENV['ProgramFiles']/7-zip}\""
windows_package node['7-zip']['package_name'] do
  source node['7-zip']['url']
  action :install
end

# Install GIT 1.9.5
windows_package node['git']['display_name'] do
  action :install
  source node['git']['url']
  checksum node['git']['checksum']
  installer_type :inno
end

# Git is installed to Program Files (x86) on 64-bit machines and
# 'Program Files' on 32-bit machines
PROGRAM_FILES = ENV['ProgramFiles(x86)'] || ENV['ProgramFiles']
GIT_PATH = "#{ PROGRAM_FILES }\\Git\\Cmd"

# COOK-3482 - windows_path resource doesn't change the current process
# environment variables. Therefore, git won't actually be on the PATH
# until the next chef-client run
ruby_block 'Add Git Path' do
  block do
    ENV['PATH'] += ";#{GIT_PATH}"
  end
  action :nothing
end

windows_path GIT_PATH do
  action :add
  notifies :create, 'ruby_block[Add Git Path]', :immediately
end

# Set up the git default configuration. Because we assume the machine is only
# used for one purpose we can set the global configuration instead of the per user
# one (which is much harder to create given that Windows doesn't allow us to create
# the c:\Users\jenkins_master directory by ourselves).
GIT_CONFIG_PATH = "#{ PROGRAM_FILES }\\Git\\etc\\gitconfig"
file GIT_CONFIG_PATH do
  content <<-INI
[user]
    name = jenkins.master
    email = jenkins.master@cloud.jenkins.com
[credential]
    helper = wincred
[core]
    symlinks = false
    autocrlf = false
[color]
    diff = auto
    status = auto
    branch = auto
    interactive = true
[pack]
    packSizeLimit = 2g
[help]
    format = html
[http]
    sslCAinfo = /bin/curl-ca-bundle.crt
[sendemail]
    smtpserver = /bin/msmtp.exe
[diff "astextplain"]
    textconv = astextplain
[rebase]
    autosquash = true
  INI
  action :create
end

# Install Java JRE 8 (server JRE tar.gz package)
java_install_directory = 'c:\\java'
powershell_script 'install_java' do
  code <<-POWERSHELL
    $ErrorActionPreference = 'Stop'

    $sevenzip = 'c:/Program Files/7-zip/7z.exe'

    $configurationDir = "#{configuration_directory}"
    $javaTarGz = Join-Path $configurationDir 'server-jre-8u25-windows-x64.gz'
    if (-not (Test-Path $javaTarGz))
    {
        throw "Could not locate $javaTarGz"
    }

    $extractionDir = Join-Path $configurationDir "extract"
    & $sevenzip x -y -o"$extractionDir" $javaTarGz

    $javaDir = "#{java_install_directory}"
    if (Test-Path $javaDir)
    {
        Remove-Item -Path $javaDir -Force -Recurse -ErrorAction SilentlyContinue
    }

    $javaTar = Join-Path $extractionDir 'server-jre-8u25-windows-x64'
    if (-not (Test-Path $javaTar))
    {
        throw "Could not locate $javaTar"
    }

    & $sevenzip x -y -o"$javaDir" $javaTar
  POWERSHELL
end

directory ci_directory do
  action :create
end

# Copy Jenkins.war file
remote_file "#{ci_directory}\\#{jenkins_java_file_name}" do
  source 'http://mirrors.jenkins-ci.org/war/1.595/jenkins.war'
end

# Copy Java service runner & rename to jenkins.exe
remote_file "#{ci_directory}\\#{service_name}.exe" do
  source 'http://repo.jenkins-ci.org/releases/com/sun/winsw/winsw/1.16/winsw-1.16-bin.exe'
end

# Create jenkins.exe.config
file "#{ci_directory}\\#{service_name}.exe.config" do
  content <<-XML
<configuration>
    <runtime>
        <generatePublisherEvidence enabled="false"/>
    </runtime>
    <startup>
        <supportedRuntime version="v4.0" />
        <supportedRuntime version="v2.0.50727" />
    </startup>
</configuration>
  XML
  action :create
end

# create java SSL cert file like here: http://stackoverflow.com/a/9610431/539846

# Create jenkins.xml
# run as https:
# <arguments>-Xrs -Xmx512m -Dhudson.lifecycle=hudson.lifecycle.WindowsServiceLifecycle -jar "%BASE%/jenkins.war" --httpPort=-1 --httpsPort=43 --httpsKeyStore=path/to/keystore --httpsKeyStorePassword=keystorePassword</arguments>
file "#{ci_directory}\\#{service_name}.xml" do
  content <<-XML
<?xml version="1.0"?>
<!--
    The MIT License Copyright (c) 2004-2009, Sun Microsystems, Inc., Kohsuke Kawaguchi Permission is hereby granted, free of charge, to any person obtaining a
    copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
    PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
    OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
-->

<service>
    <id>#{service_name}</id>
    <name>#{service_name}</name>
    <description>This service runs the Jenkins continuous integration system.</description>
    <env name="JENKINS_HOME" value="%BASE%"/>

    <!-- if you'd like to run Jenkins with a specific version of Java, specify a full path to java.exe. The following value assumes that you have java in your PATH. -->
    <executable>#{java_install_directory}\\jdk1.8.0_25\\bin\\java.exe</executable>
    <arguments>-Xrs -Xmx512m -Dhudson.lifecycle=hudson.lifecycle.WindowsServiceLifecycle -jar "%BASE%\\#{jenkins_java_file_name}" --httpPort=8080</arguments>

    <!-- interactive flag causes the empty black Java window to be displayed. I'm still debugging this. <interactive /> -->
    <logmode>rotate</logmode>
    <onfailure action="restart"/>
</service>
    XML
  action :create
end

# Install jenkins.exe as service
powershell_script 'jenkins_as_service' do
  code <<-POWERSHELL
    $ErrorActionPreference = 'Stop'

    Write-Host "JenkinsUser: #{jenkins_username}"
    Write-Host "JenkinsPassword: #{jenkins_password}"

    $securePassword = ConvertTo-SecureString "#{jenkins_password}" -AsPlainText -Force

    # Note the .\\ is to get the local machine account as per here:
    # http://stackoverflow.com/questions/313622/powershell-script-to-change-service-account#comment14535084_315616
    $credential = New-Object pscredential((".\\" + "#{jenkins_username}"), $securePassword)

    New-Service -Name '#{service_name}' -BinaryPathName '#{ci_directory}\\#{service_name}.exe' -Credential $credential -DisplayName '#{service_name}' -StartupType Automatic
  POWERSHELL
end

env 'JENKINS_HOME' do
  value ci_directory
  action :create
end

# Create the event log source for the jenkins service. We'll create it now because the service runs as a normal user
# and is as such not allowed to create eventlog sources
registry_key "HKEY_LOCAL_MACHINE\\SYSTEM\\CurrentControlSet\\services\\eventlog\\Application\\#{service_name}" do
  values [{
    name: 'EventMessageFile',
    type: :string,
    data: 'c:\\Windows\\Microsoft.NET\\Framework64\\v4.0.30319\\EventLogMessages.dll'
  }]
  action :create
end
