@Echo Off
Rem ******************************************************************
Rem  Revision date: 2023.07.04
Rem 
Rem  Copyright (c) 2023 PC-Évolution enr.
Rem  This code is licensed under the GNU General Public License (GPL).
Rem 
Rem  THIS CODE IS PROVIDED *AS IS* WITHOUT WARRANTY OF
Rem  ANY KIND, EITHER EXPRESS OR IMPLIED, INCLUDING ANY
Rem  IMPLIED WARRANTIES OF FITNESS FOR A PARTICULAR
Rem  PURPOSE, MERCHANTABILITY, OR NON-INFRINGEMENT.
Rem 
Rem ******************************************************************


SetLocal EnableDelayedExpansion

Echo.
Rem Display text according to the default Windows page instead of using the OEM code page (most likely 850)
chcp 1252 > NULL

Echo Recovery Drive: %~dp0
Echo -------------------
Echo.

Rem Install temporary workaround for Windows builds 20348 and above
if exist "%~dp0\Empty.evtx" (

	net Stop EventLog

	Copy "%~dp0\Empty.evtx" %SystemRoot%\System32\WinEvt\Logs\System.evtx
	Copy "%~dp0\Empty.evtx" %SystemRoot%\System32\WinEvt\Logs\Application.evtx

	net Start EventLog

	net Start W32Time
	reg Query HKLM\SYSTEM\CurrentControlSet\Control\TimeZoneInformation /v TimeZoneKeyName
	echo %Date% %Time%
	echo.

	wevtutil gli System
	echo.

	wevtutil gli Application
	echo.

	Rem "net stop W32Time" will result in a error 2 (File not found),
	Rem an indication that some other Event log is missing.
 )

if exist "%~dp0\Drivers\pnputil.exe" (

	Set PnP=Non
	Echo Do you want to install the OEM drivers present on the recovery drive?
	Set /P PnP=Enter "Yes" ^(case sensitive^) to install, anything else list installed OEM drivers: 
	Echo.

	if "[!PnP!]" equ "[Yes]" (
		"%~dp0\Drivers\pnputil.exe" /add-driver "%~dp0\Drivers\*.inf" /subdirs /install
	) else (
		"%~dp0\Drivers\pnputil.exe" /enum-drivers
	)

 ) else (
	Echo The OEM driver installation utility does not exist in the directory "%~dp0\Drivers"
	Echo.
 )

Echo.

SetLocal DisableDelayedExpansion


Echo Network Initialization:
Echo -----------------------
Echo.


Rem Start the DNS Client
net start dnscache 2> NUL

Rem Initialize the Network Stack
chcp 850 > NULL
ping localhost > NUL || wpeutil InitializeNetwork
chcp 1252 > NULL

Rem Prompt the user to review the network configuration
ping localhost > NUL && ipconfig /all
Echo.
Set /P Junk=Confirm that the network is configured correctly or press (Ctrl)C to drop the connection to a network disk:

Rem Start the iSCSI Initiator Service
Echo.
net start msiscsi 2> NUL

:GetPortal
Echo.
Set /P Portal=Enter the iSCSI server (IP address or hostname): 
If [%Portal%] == [] goto SkipiSCSI
iscsicli QAddTargetPortal %Portal% || goto GetPortal
Echo.

:GetTarget
iscsicli listTargets
Echo.
Set /P TargetName=Enter the iSCSI target: 
iscsicli QLoginTarget %TargetName% || goto GetTarget

Echo.
Echo Wait for iSCSI disk integration into Windows configuration (60 seconds)
ping -4 -n 60 %Portal% > NUL
:SkipiSCSI

Rem Review the configuration of disks and partitions
Echo.
Echo Review the configuration of disks and partitions (finish with the 'exit' command):
%windir%\system32\diskpart.exe

Rem View Available Discs
Echo.
Echo Available Discs:
mountvol | find "\"
Echo.

Rem Start the Restore Utility
Start %windir%\system32\bmrui.exe

