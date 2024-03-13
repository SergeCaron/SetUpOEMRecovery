##******************************************************************
## Revision date: 2024.03.13
##
##		2022.07.08: Proof of concept / Initial release
##		2023.07.04: Closure of Microsoft 2304230060000186: workaround MSiSCSI bug
##		2024.01.31: Skip non-existent language packs
##		2024.02.08: Revise translation
##
## Copyright (c) 2022-2024 PC-Évolution enr.
## This code is licensed under the GNU General Public License (GPL).
##
## THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
## ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
## IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
## PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
##
##******************************************************************

#
Write-Host ""
Write-Host $([System.Environment]::OSVersion.VersionString)
Write-Host ""

# Required USB key size: sometime after Windows 10 (1809)/Windows Server 2019, the required key size is 16GB
$TargetSize = 8GB
If ([System.Environment]::OSVersion.Version.Build -gt 17763) { $TargetSize = 16GB }

Do {
	Do {
		$Junk = Read-Host -Prompt "Make sure a Microsoft RecoveryDrive compatible USB drive is connected and press RETURN to continue"
		# Enumerate compatible USB drives (MBR with single partition and appropriate size)
		# Note:	under the MBR scheme, a single partition cannot contain more than a single volume
		#		(see https://learn.microsoft.com/en-us/windows/win32/fileio/basic-and-dynamic-disks)
		[System.Object[]] $TargetVolumes = Get-Disk | Where-Object -FilterScript { $_.Bustype -Eq "USB" -and $_.PartitionStyle -Eq "MBR" -and ($_.NumberOfPartitions -eq 1) -and $_.Size -ge 4GB } `
		| Get-Partition | Get-Volume
		# Quick display ;-)
		Write-Warning "The Microsoft RecoveryDrive utility will enumerate 'Fixed' and 'Removable' drive types."
		$TargetVolumes | Format-Table -AutoSize
	} Until ( $TargetVolumes.Count -gt 0)

	# Do we already have a Recovery Drive (or something that looks like it ;-)
	$TargetVolume = @()
	ForEach ($Volume in $TargetVolumes.DriveLetter) { if ( Test-Path -Path "$Volume`:\sources\Reconstruct.WIM" -PathType Leaf ) { $TargetVolume += $Volume } }

	If ($TargetVolume.Count -eq 0) {
		$Junk = Read-Host -Prompt "Press RETURN to invoke the RecoveryDrive creator"
		# Create a Recovery Drive
		Start-Process -FilePath $Env:windir\System32\RecoveryDrive.exe -Wait
		# We don't have of clue of what happened in the past few HOURS (most likely ...) or the last few minutes if user cancelled the RecoveryDrive creator
	}
	ElseIf ($TargetVolume.Count -gt 1) {
		Write-Host "These appear to be valid recovery drives:"
		$TargetVolume | ForEach-Object { "  $_`:\" }
		Write-Warning "Please connect a single Recovery Drive!"
		Write-Warning ""
	}
	Else {
		# Make a scalar out of this array
		[String] $USBRecovery = "$TargetVolume`:"
		# Do not reinitialize the USB drive from which we are running ;-)
		If ( $(Split-Path -Path $MyInvocation.InvocationName -Parent) -ne "$USBRecovery\" ) {
			If ( $(Get-Volume -DriveLetter $TargetVolume).Size -ge $TargetSize ) {
				If ($(Read-Host "Enter 'Yes' to reinitialize this Recovery Drive ($USBRecovery), anything else to continue").tolower().StartsWith('yes')) {
					# Create a Recovery Drive
					Start-Process -FilePath $Env:windir\System32\RecoveryDrive.exe -Wait
					# It has been a long time: force a new scan of USB drives
					$TargetVolume = @()
				}
			}
			Else { Write-Warning "Drive $$USBRecovery is too small to create a Recovery Drive from this system" }
		}
	}
} Until ( $TargetVolume.Count -eq 1 )

# Set up the directory structure expected by the "Recover.cmd" utility in the WinPE environment
$USBRecovery = "$TargetVolume`:"
Write-Host "Updating drive $USBRecovery with OEM drivers from this system."

# Only copy Microsoft utilities when the creating the ...\Drivers directory.
if ( Test-Path -Path "$USBRecovery\Drivers" -PathType Container ) {
	Write-Warning ""
	Write-Warning "$USBRecovery\Drivers already exist: make sure older contents will not impact recovery of this system."
	Write-Warning ""
}
else {
	New-Item "$USBRecovery\Drivers" -ItemType Directory

	# For some reason, PnPUtil is not part of the "standard" recovery environment.
	# Unfortunately, you can't mix and match utilities from various builds.
	# Let's presume this USB key was created on this system ;-)
		
	Copy-Item -Path "$Env:WinDir\System32\PnPUtil.exe" -Destination "$USBRecovery\Drivers"

	# That is too simple ;-) $Ressources = (Get-WinSystemLocale).Name
	# Get installed languages
	$LanguagePacks = (Get-WmiObject -Class Win32_OperatingSystem).MUILanguages

	ForEach ( $Ressources in $LanguagePacks ) {
		if ( Test-Path -Path "$USBRecovery\Drivers\$Ressources" -PathType Container )
		{ Write-Warning "$USBRecovery\Drivers\$Ressources already exists." }
		else { New-Item "$USBRecovery\Drivers\$Ressources" -ItemType Directory }

		Try {
			Copy-Item -Path "$Env:WinDir\System32\$Ressources\PnPUtil.exe.mui" `
				-Destination "$USBRecovery\Drivers\$Ressources" -ErrorAction Stop 
		}
		Catch { Write-Warning "Skipping $USBRecovery\Drivers\$Ressources\PnPUtil.exe.mui" }
	}
}

# Copy/override utilities
If ($(Split-Path -Path $MyInvocation.InvocationName -Parent) -ne "$USBRecovery\") {
	Copy-Item -Path $MyInvocation.InvocationName -Destination "$USBRecovery\"
	Copy-Item -Path $MyInvocation.InvocationName.Replace($MyInvocation.MyCommand, "Recover.cmd") -Destination "$USBRecovery\"
	Copy-Item -Path $MyInvocation.InvocationName.Replace($MyInvocation.MyCommand, "Empty.evtx") -Destination "$USBRecovery\"
}

# Export all OEM drivers
pnputil /export-driver * "$USBRecovery\Drivers"

# Get the driver class and purge what will be unnecessary in a WinPE environment
# These are the classes deemed "unnecessary" :
$UnnecessaryClassesInWinPE = @("DISPLAY", "MEDIA", "BLUETOOTH", "PRINTER", "SOFTWARECOMPONENT")

$Drivers = Get-ChildItem -Path "$USBRecovery\Drivers\*" -Directory -Depth 0 | Sort-Object -Property Name
$DriversWithClass = @()
ForEach ($Driver in $Drivers) {
 $Infs = Get-ChildItem -Path $($Driver.FullName + "\\*.inf") -File -Depth 0
	ForEach ($Inf in $Infs) {
		Get-Content $Inf.FullName | Where-Object { $_ -Match '^\s*Class\s*=\s*(\S*)' } | `
				ForEach-Object {
				$DriverClass = $Matches[1].ToUpper()
				If ($UnnecessaryClassesInWinPE.Contains($DriverClass) ) {
					$DriversWithClass += New-Object PSObject -Property @{ 
						Driver = $Driver.FullName 
						Class  = $DriverClass
					}
				}
			}
	}
}
if ($DriversWithClass.Count -gt 0) {
	Write-Warning "These drivers are probably useless in the Windows PE environment:"
	ForEach ( $Candidate in $DriversWithClass )
	{ Write-Warning "  $Candidate " }
	If ($(Read-Host "Enter 'Yes' to remove these drivers, anything else to continue").tolower().StartsWith('yes')) {
		ForEach ( $Candidate in $DriversWithClass )
		{ Remove-Item -LiteralPath $Candidate.Driver -Force -Recurse }
		# Re-enumerate what is left ;-)
		$Drivers = Get-ChildItem -Path "$USBRecovery\Drivers\*" -Directory -Depth 0 | Sort-Object -Property Name
	}
}

# Highlight anything that is bigger than some arbitrary value (40MB is the default)
# These drivers are probably useless in the WinPE envritonment and will likely fill the RAM disk at runtime.
$LargeDrivers = $Drivers | Where-Object { $(Get-ChildItem $_.FullName -Recurse -File | Measure-Object -Property Length -Sum | Select-Object -ExpandProperty Sum) -ge 40mb }
if ($LargeDrivers.Count -gt 0) {
	Write-Warning "These drivers are probably useless in the Windows PE environment:"
	ForEach ( $LargeDriver in $LargeDrivers )
	{ Write-Warning "  $LargeDriver" }
	
	If ($(Read-Host "Enter 'Yes' to remove these drivers, anything else to continue").tolower().StartsWith('yes')) {
		ForEach ( $LargeDriver in $LargeDrivers )
		{ Remove-Item -LiteralPath $LargeDriver.FullName -Force -Recurse }
	}
}
	  
# Enumerate drivers
Write-Host ""
Write-Host "Available OEM drivers on this recovery media:"
Write-Host "---------------------------------------------"
Write-Host ""
$Drivers = Get-ChildItem -Path "$USBRecovery\Drivers\*" -Directory -Depth 1 | Sort-Object -Property Name
$Drivers | Format-Table Name, LastWriteTime -AutoSize

 
	  
# That's it ;-)
Write-Host ""
Write-Host "Done!"
