#Install codecov to upload results
Write-Host -Object "appveyor.prep: Install codecov" -ForegroundColor DarkGreen
choco install codecov | Out-Null

# "Get Pester manually"
Write-Host -Object "appveyor.prep: Install Pester" -ForegroundColor DarkGreen
Install-Module -Name Pester -Repository PSGallery -Force | Out-Null