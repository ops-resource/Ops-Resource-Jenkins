require File.join(File.dirname(__FILE__), '..', 'spec_helper')

# Verify that the opscode directory is not there
describe command('powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Test-Path c:\opscode"') do
  its(:stdout) { should match 'False' }
end

# Verify that the .chef directory is not there
describe command('powershell.exe -NoLogo -NoProfile -NonInteractive -Command "Test-Path c:\opscode"') do
  its(:stdout) { should match 'False' }
end
