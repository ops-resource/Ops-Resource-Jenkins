require File.join(File.dirname(__FILE__), '..', 'spec_helper')
require 'rest_client'

describe file('c:/ci') do
  it { should be_directory }
end

describe file('c:/ci/jenkins.exe') do
  it { should be_file }
end

describe file('c:/ci/jenkins.exe.config') do
  it { should be_file }
end

describe file('c:/ci/jenkins.war') do
  it { should be_file }
end

describe file('c:/ci/jenkins.xml') do
  it { should be_file }
end

describe service('Jenkins') do
  it { should be_installed }
  it { should be_enabled }
  it { should have_start_mode('automatic')  }
  it { should be_running }
end

# Verify that the service is running as the jenkins_master user
get_wmi_command = 'Get-WmiObject win32_service -computer . -property name, startname, caption'
where_object_command = ' | Where-Object { $_.name -match "jenkins" }'
select_object_command = ' | Select-Object -First 1'
select_service_command = '$service = ' + get_wmi_command + where_object_command + select_object_command

verify_user_command = 'if ($service.startname -notmatch ".\\\\jenkins_master"){ Write-Output "FAIL"; exit 1 }'

invoke_powershell_command = 'powershell.exe -NoLogo -NonInteractive -NoProfile -Command \'' + select_service_command + ';' + verify_user_command + '\''
describe command(invoke_powershell_command) do
  its(:stdout) { should match '' }
  its(:exit_status) { should eq 0 }
end

# if the service is running then jenkins should be available on port 8080
describe port(8080) do
  it { should be_listening.with('tcp') }
end

# Query the version of jenkins that is running
describe 'jenkins webservice' do
  response = RestClient.get 'http://localhost:8080/api/json'
  it 'is active an returns the correct version' do
    expect(response.headers['X-Jenkins']).to eq('1.595')
  end
end
