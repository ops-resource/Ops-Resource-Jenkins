#
# Cookbook Name:: slave_windows
# Recipe:: default
#
# Copyright 2014, Vista Entertainment Ltd.
#
# All rights reserved - Do Not Redistribute
#

include_recipe 'windows'

# Create user
# - limited user (from AD?)
# - Reduce access to files. User should only have write access to Jenkins dir and workspaces

# Install 7-zip
include_recipe '7-zip'

# Install GIT 1.9.5
include_recipe 'git::windows'

# Install .gitconfig with the following values:
# [user]
#     name = username
#     email = username@server.domain
# [core]
#     autocrlf = false
# [credential]
#     helper = !\"C:/Program Files (x86)/Git/libexec/git-core/git-credential-wincred.exe\"

# Install Java JRE 8 (server JRE tar.gz package)



# Copy Jenkins.jar file
# Copy Java service runner & rename to jenkins.exe
# Create jenkins.exe.config
# Create jenkins.xml
# - set it to run as https in the config as well
# create java SSL cert file like here: http://stackoverflow.com/a/9610431/539846

# <?xml version="1.0"?>
# <!-- 
#     The MIT License Copyright (c) 2004-2009, Sun Microsystems, Inc., Kohsuke Kawaguchi Permission is hereby granted, free of charge, to any person obtaining a 
#     copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights 
#     to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, 
#     subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. 
#     THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
#     PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
#     OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
# -->
# 
# <!-- 
#     Windows service definition for Jenkins. To uninstall, run "jenkins.exe stop" to stop the service, then "jenkins.exe uninstall" to uninstall the 
#     service. Both commands don't produce any output if the execution is successful. 
# -->
# <service>
#     <id>jenkins</id>
#     <name>Jenkins</name>
#     <description>This service runs the Jenkins continuous integration system.</description>
#     <env name="JENKINS_HOME" value="%BASE%"/>
#     
#     <!-- if you'd like to run Jenkins with a specific version of Java, specify a full path to java.exe. The following value assumes that you have java in your PATH. -->
#     <executable>C:\Program Files\Java\jre8\bin\java.exe</executable>
#     <arguments>-Xrs -Xmx256m -Dhudson.lifecycle=hudson.lifecycle.WindowsServiceLifecycle -jar "%BASE%\jenkins.war" --httpPort=-1 --httpsPort=43 --httpsKeyStore=path/to/keystore --httpsKeyStorePassword=keystorePassword</arguments>
#     
#     <!-- interactive flag causes the empty black Java window to be displayed. I'm still debugging this. <interactive /> -->
#     <logmode>rotate</logmode>
#     <onfailure action="restart"/>
# </service>


# Install jenkins.exe as service
# - Running as specific domain user
# - Start automatic

# Secure Jenkins
# - AD?

# Import jobs? --> maybe do that when the image is actually started for production