require File.join(File.dirname(__FILE__), '..', 'spec_helper')

# verify that the correct Java version is installed.
describe file('c:/java') do
  it { should be_directory }
end

describe file('C:/java/jdk1.8.0_25') do
  it { should be_directory }
end

describe file('C:/java/jdk1.8.0_25/bin') do
  it { should be_directory }
end

describe file('C:/java/jdk1.8.0_25/bin/java.exe') do
  it { should be_file }
  it { should be_version('8.0.25.18') }
end
