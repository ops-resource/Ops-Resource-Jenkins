# Windows settings
node['windows']['allow_pending_reboots'] = 'false'

# Install 7-zip
node['7-zip']['home']                    = "%ProgramFiles%/7-zip"

# install GIT
node['git']['version']                   = '1.9.5'
node['git']['url']                       = 'https://github.com/msysgit/msysgit/releases/download/Git-1.9.5-preview20141217/Git-1.9.5-preview20141217.exe'
node['git']['checksum']                  = 'D7E78DA2251A35ACD14A932280689C57FF9499A474A448AE86E6C43B882692DD'
node['git']['display_name']              = 'Git version 1.9.5-preview20141217'