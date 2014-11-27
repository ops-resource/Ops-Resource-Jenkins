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