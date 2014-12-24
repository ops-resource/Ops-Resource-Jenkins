name             'master'
maintainer       '${CompanyName} (${CompanyUrl})'
maintainer_email 'YOUR_EMAIL'
license          'All rights reserved'
description      'Installs/Configures a Jenkins master on a Windows server'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '${VersionSemantic}'

supports         "windows"

depends          'java', '~> 1.29.0'
depends          'windows', '~> 1.36.1'
depends          'ms_dotnet35', '~> 1.0.1'
depends          'ms_dotnet45', '~> 2.0.0'
depends          'powershell', '~> 3.0.7'
depends          '7-zip', '~> 1.0.2'
depends          'chocolatey', '~> 0.2.0'
depends          'git', '~> 4.0.2'
depends          'jenkins', '~> 2.2.1'