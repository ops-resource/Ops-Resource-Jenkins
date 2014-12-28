# verify that the correct Java version is installed. See: https://www.java.net/node/661905 for keys
describe windows_registery_key('HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432\JavaSoft\Java Runtime Environment') do
  it { should have_property('Java8FamilyVersion', :type_string) }
end

describe windows_registery_key('HKEY_LOCAL_MACHINE\SOFTWARE\Wow6432\JavaSoft\Java Runtime Environment Java8FamilyVersion') do
  it { should have_value('1.8.0_11') }
end

# Verify that JAVA is NOT in the PATH
