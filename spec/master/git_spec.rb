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
git_config_content = <<-INI
[user]
    name = jenkins.master
    email = jenkins.master@cloud.jenkins.com
[credential]
    helper = wincred
[core]
    symlinks = false
    autocrlf = false
[color]
    diff = auto
    status = auto
    branch = auto
    interactive = true
[pack]
    packSizeLimit = 2g
[help]
    format = html
[http]
    sslCAinfo = /bin/curl-ca-bundle.crt
[sendemail]
    smtpserver = /bin/msmtp.exe
[diff "astextplain"]
    textconv = astextplain
[rebase]
    autosquash = true
  INI

describe file('c:/program files (x86)/Git/etc/gitconfig') do
  it { should be_file }
  its(:content) { should start_with(git_config_content) }
end
