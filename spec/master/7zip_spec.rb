require File.join(File.dirname(__FILE__), '..', 'spec_helper')

# verify that the correct 7-Zip version is installed.
describe file('c:/program files') do
  it { should be_directory }
end

describe file('c:/program files/7-Zip') do
  it { should be_directory }
end

describe file('c:/program files/7-Zip/7z.exe') do
  it { should be_file }
  it { should be_version('9.36 beta') }
end
