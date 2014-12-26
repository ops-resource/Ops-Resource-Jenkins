require 'chefspec'

RSpec.configure do |config|
  # Specify the path for Chef Solo to find cookbooks (default: [inferred from
  # the location of the calling spec file])
  # config.cookbook_path = '/var/cookbooks'

  # Specify the path for Chef Solo to find roles (default: [ascending search])
  # config.role_path = '/var/roles'

  # Specify the path for Chef Solo to find environments (default: [ascending search])
  # config.environment_path = '/var/environments'

  # Specify the Chef log_level (default: :warn)
  config.log_level = :debug

  # Specify the path to a local JSON file with Ohai data (default: nil)
  # config.path = 'ohai.json'

  # Specify the operating platform to mock Ohai data from (default: nil)
  config.platform = 'windows'

  # Specify the operating version to mock Ohai data from (default: nil)
  config.version = '2012'
end

describe 'master'  do
    let(:chef_run) { ChefSpec::SoloRunner.converge(described_recipe) }

    # Create user jenkins_master
    # is granted run-as-service permissions?
    it 'creates the jenkins_master user' do
        expect(chef_run).to create_user('jenkins_master')
    end

    # Install 7-zip (c:\program files\7-zip --> 9.34)
    it 'installs 7-zip' do
        expect(chef_run).to install_package('7-zip')
    end

    # install git (c:\program files (x86)\git --> 1.9.5)
    it 'installs git' do
        expect(chef_run).to install_windows_package('git')
        expect(chef_run).to add_windows_path('stuff')
    end

    # install java (c:\java)
    it 'installs java' do
        expect(chef_run).to run_powershell_script('install_java')
    end

    # install jenkins.jar
    it 'creates jenkins.war in the ci directory' do
        expect(chef_run).to create_file('c:\ci\jenkins.war')
    end

    # install jenkins.exe
    it 'creates jenkins.exe in the ci directory' do
        expect(chef_run).to create_file('c:\ci\jenkins.exe')
    end

    # install jenkins.config.exe
    jenkins_exe_config_content = <<-XML
<configuration>
  <runtime>
    <generatePublisherEvidence enabled="false"/> 
  </runtime>
  <startup>
    <supportedRuntime version="v4.0" />
    <supportedRuntime version="v2.0.50727" />
  </startup>
</configuration>
    XML

    it 'creates jenkins.exe.config in the ci directory' do
        expect(chef_run).to create_file('c:\ci\jenkins.exe.config').with_content(jenkins_exe_config_content)
    end


    # create java SSL cert file like here: http://stackoverflow.com/a/9610431/539846

    # install jenkins.xml
    jenkins_xml_content = <<-XML
<?xml version="1.0"?>
<!-- 
    The MIT License Copyright (c) 2004-2009, Sun Microsystems, Inc., Kohsuke Kawaguchi Permission is hereby granted, free of charge, to any person obtaining a 
    copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights 
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, 
    subject to the following conditions: The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software. 
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A 
    PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION 
    OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 
-->

<!-- 
    Windows service definition for Jenkins. To uninstall, run "jenkins.exe stop" to stop the service, then "jenkins.exe uninstall" to uninstall the 
    service. Both commands don't produce any output if the execution is successful. 
-->
<service>
    <id>jenkins</id>
    <name>Jenkins</name>
    <description>This service runs the Jenkins continuous integration system.</description>
    <env name="JENKINS_HOME" value="%BASE%"/>
    
    <!-- if you'd like to run Jenkins with a specific version of Java, specify a full path to java.exe. The following value assumes that you have java in your PATH. -->
    <executable>C:\\java\\bin\\java.exe</executable>
    <arguments>-Xrs -Xmx512m -Dhudson.lifecycle=hudson.lifecycle.WindowsServiceLifecycle -jar "%BASE%\\jenkins.war" --httpPort=-1 --httpsPort=43 --httpsKeyStore=path/to/keystore --httpsKeyStorePassword=keystorePassword</arguments>
    
    <!-- interactive flag causes the empty black Java window to be displayed. I'm still debugging this. <interactive /> -->
    <logmode>rotate</logmode>
    <onfailure action="restart"/>
</service>
    XML
    it 'creates jenkins.xml in the ci directory' do
        expect(chef_run).to create_file('c:\ci\jenkins.xml').with_content(jenkins_xml_content)
    end

    # windows service jenkins
    #   startuptype automatic
    #   running
    #   jenkins_master user
    # install java (c:\java)
    it 'installs jenkins as service' do
        expect(chef_run).to run_powershell_script('jenkins_as_service')
    end
end