require 'chefspec'

describe 'azure jenkins master'  do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    it 'creates a temp directory' do
        expect(chef_run).to create_directory('c:\temp')
    end

    it 'creates a file in the temp directory' do
        expect(chef_run).to create_file('c:\temp\myfile.txt').with_content('This is a test')
    end
end