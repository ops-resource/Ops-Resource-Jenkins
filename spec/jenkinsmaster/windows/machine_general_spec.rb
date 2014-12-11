require 'spec_helper'

describe file('c:\temp') do
    it { should be_directory }
end

describe file('c:\temp\myfile.txt') do
    it { should be_file }
end

describe file('c:\temp\myfile.txt') do
    its(:content) { should match 'This is a test'}
end
