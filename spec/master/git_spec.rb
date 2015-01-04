require File.join(File.dirname(__FILE__), '..', 'spec_helper')

# verify that the correct git version is installed.
describe file('c:/program files (x86)') do
  it { should be_directory }
end

describe file('c:/program files (x86)/Git') do
  it { should be_directory }
end

describe file('c:/program files (x86)/Git/cmd') do
  it { should be_directory }
end

describe file('c:/program files (x86)/Git/cmd/git.exe') do
  it { should be_file }
end

# versify that git has been added to the PATH
describe command('powershell.exe -NoLogo -NonInteractive -NoProfile -Command "& git --version"') do
  its(:stderr) { should match '' }
  its(:stdout) { should match 'git version 1.9.5.msysgit.0' }
end

# User configuration has been set-up
