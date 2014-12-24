# .NET 3.5 has been installed. See: http://support.microsoft.com/kb/318785 for the registry key values
describe windows_registery_key('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5') do
    it { should have_property('Install', :type_dword) }
    it { should have_property('SP', :type_dword) }
end

describe windows_registery_key('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5 Install') do
    it { should have_value('1') }
end

describe windows_registery_key('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v3.5 SP') do
    it { should have_value('1') }
end

# .NET 4.5.1 has been installed. See: http://msdn.microsoft.com/en-us/library/hh925568.aspx for key values
describe windows_registery_key('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full') do
    it { should have_property('Release', :type_dword) }
end

describe windows_registery_key('HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full Release') do
    it { should have_value('378675') }
end