require File.join(File.dirname(__FILE__), '..', 'spec_helper')

# .NET 4.5.1 has been installed. See: http://msdn.microsoft.com/en-us/library/hh925568.aspx for key values
describe windows_registry_key('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full') do
  it { should have_property('Release', :type_dword) }
end

describe windows_registry_key('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full') do
  it { should have_property_value('Release', :type_dword, '0x0005c733') }
end

describe user('jenkins_master') do
  it { should exist }
end

# Verify the user has log-on-as-service rights
