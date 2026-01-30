###############################################################
#
## Copyright (©) 2026 International Color Consortium.
##                 All rights reserved.
##                 https://color.org
#
# Last Modified: 30-JAN-2026 1800Z by David Hoyt
# Intent: Windows PR-555 Build Script
#
#
# iex (iwr -Uri "https://raw.githubusercontent.com/InternationalColorConsortium/iccDEV/refs/heads/research/contrib/HelperScripts/pr555.ps1").Content
#
#
#
###############################################################

Write-Host "============================= Starting Windows Build for PR-555 =============================" -ForegroundColor Green
Write-Host "Last Updated: 30-JAN-2026 2000Z by David H Hoyt LLC" -ForegroundColor Green
git clone https://github.com/InternationalColorConsortium/iccDEV.git
cd iccDEV
git fetch origin pull/555/head:pr-555
git checkout pr-555
          Write-Host "========= Fetching Deps... ================`n"
          Start-BitsTransfer -Source "https://github.com/InternationalColorConsortium/iccDEV/releases/download/v2.3.1/vcpkg-exported-deps.zip" -Destination "deps.zip"
          Write-Host "========= Extracting Deps... ================`n"
          tar -xf deps.zip
          cd Build/Cmake
          Write-Host "========= Building... ================`n"  
          cmake  -B build -S . -DCMAKE_TOOLCHAIN_FILE="..\..\scripts\buildsystems\vcpkg.cmake" -DVCPKG_MANIFEST_MODE=OFF -DCMAKE_BUILD_TYPE=Debug  -Wno-dev
          cmake --build build -- /m /maxcpucount
          cmake --build build -- /m /maxcpucount   
          $exeDirs = Get-ChildItem -Recurse -File -Include *.exe -Path .\build\ |
              Where-Object { $_.FullName -match 'icc' -and $_.FullName -notmatch '\\CMakeFiles\\' -and $_.Name -notmatch '^CMake(C|CXX)CompilerId\.exe$' } |
              ForEach-Object { Split-Path $_.FullName -Parent } |
              Sort-Object -Unique
          $env:PATH = ($exeDirs -join ';') + ';' + $env:PATH
          $env:PATH -split ';' | Select-String "icc"
          $toolDirs = Get-ChildItem -Recurse -File -Include *.exe -Path .\Tools\ | ForEach-Object { Split-Path -Parent $_.FullName } | Sort-Object -Unique
          $env:PATH = ($toolDirs -join ';') + ';' + $env:PATH
          $env:PATH -split ';'
          pwd
          cd ..\..\Testing
          .\CreateAllProfiles.bat
          .\RunTests.bat
          cd CalcTest\
          .\checkInvalidProfiles.bat
          .\runtests.bat
          cd ..\Display
          .\RunProtoTests.bat
          cd ..\HDR
          .\mkprofiles.bat
          cd ..\mcs\
          .\updateprev.bat
          .\updateprevWithBkgd.bat
          cd ..\Overprint
          .\RunTests.bat
          cd ..
          cd hybrid
          .\BuildAndTest.bat
          cd ..
          cd ..
          pwd
          # Collect .icc profile information
          $profiles = Get-ChildItem -Path . -Filter "*.icc" -Recurse -File
          $totalCount = $profiles.Count
          
          # Group profiles by directory
          $groupedProfiles = $profiles | Group-Object { $_.Directory.FullName }
          
          # Generate Summary Report
          Write-Host "`n========================="
          Write-Host " ICC Profile Report"
          Write-Host "========================="
          
          # Print count per subdirectory
          foreach ($group in $groupedProfiles) {
              Write-Host ("{0}: {1} .icc profiles" -f $group.Name, $group.Count)
          }
          
          Write-Host "`nTotal .icc profiles found: $totalCount"
          Write-Host "=========================`n"
          
          Write-Host "All Done!"


