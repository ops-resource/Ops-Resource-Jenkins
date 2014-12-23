#
# Cookbook Name:: jenkinsmaster
# Recipe:: default
#
# Copyright 2014, YOUR_COMPANY_NAME
#
# All rights reserved - Do Not Redistribute
#
directory "c:/temp" do
    action :create
end

file "c:/temp/myfile.txt" do
  content 'This is a test'
end

# install .NET 3.5
# Install Java JRE 7 or 8, x64
# Install jenkins
# Set-up Jenkins as a service