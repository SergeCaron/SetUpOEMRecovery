# SetUpOEMRecovery

## Purpose:

Create a UEFI or MBR recovery media on a USB key containing the OEM drivers installed on the system. 
 
Drivers may be collected from multiple systems to allow using a single USB key for their maintenance.

Options allow
 removal of DISPLAY, MEDIA, BLUETOOTH, PRINTER, SOFTWARECOMPONENT drivers as well as vey large drivers (typically
 wireless NICs). These drivers are generally useless in the Windows PE environment.

The script also copies support files to initiate a bare metal restore of the system once booted
from the recovery key. This is a companion project.

------
>**Caution:**	This script requires **elevated** execution privileges.

Quoting from Microsoft's "about_Execution_Policies" : "PowerShell's
execution policy is a safety feature that controls the conditions
under which PowerShell loads configuration files and runs scripts."

Use any configuration that is the equivalent of the
following commnand executed from an elevated PowerShell prompt:

			Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
------

## Operation:

- [ ] Open an elevated PowerShell prompt.
- [ ] Invoke the script, insert a USB key and press enter. The script will prompt for a USB key until a compatible device is inserted.
- [ ] The script scans compatible USB drives for a ?:\sources\Reconstruct.WIM windows image file. If no such file is found, the script invokes the Microsoft RecoveryDrive utility. You have the option to reinitialize an existing recovery drive. Note that this utility will enumerate 'Fixed' and 'Removable' drive types, not just the selected drive. This process is repeated until a single compatible drive is identified. 
- [ ] The script dumps all OEM drivers in the ?:\Drivers directory of the USB drive. You have the option to remove drivers that are not usually used in the Windows PE environment.
- [ ] The script copies the RECOVER.CMD file in the root of the USB drive.
- [ ] An enumeration of all OEM drivers present on the drive is displayed

			
Here is a sample output:

```
	Windows PowerShell
	Copyright (C) Microsoft Corporation. All rights reserved.
	Install the latest PowerShell for new features and improvements! https://aka.ms/PSWindows    

	PS C:\Users\<WhoAmI>> cd .\Desktop\
	PS C:\Users\<WhoAmI>\Desktop> .\SetUpOEMRecovery.ps1                                               
	Microsoft Windows NT 10.0.22631.0

	Make sure a Microsoft RecoveryDrive compatible USB drive is connected and press RETURN to continue:
	WARNING: The Microsoft RecoveryDrive utility will enumerate 'Fixed' and 'Removable' drive types.

	DriveLetter FriendlyName FileSystemType DriveType HealthStatus OperationalStatus SizeRemaining     Size
	----------- ------------ -------------- --------- ------------ ----------------- -------------     ----
	E           SeaGlassUSB  FAT32          Removable Healthy      OK                     58.19 GB 58.19 GB


	Press RETURN to invoke the RecoveryDrive creator:
```
![Step_1](Ressources/Create_Recovery_Drive_Step_1
![Step_2](Ressources/Create_Recovery_Drive_Step_2
![Step_3](Ressources/Create_Recovery_Drive_Step_3
![Step_4](Ressources/Create_Recovery_Drive_Step_4
![Step_5](Ressources/Create_Recovery_Drive_Step_5

![USBKey](Ressources/Recovery_USB_Key.jpg)

```
	Make sure a Microsoft RecoveryDrive compatible USB drive is connected and press RETURN to continue:
	WARNING: The Microsoft RecoveryDrive utility will enumerate 'Fixed' and 'Removable' drive types.

	DriveLetter FriendlyName FileSystemType DriveType HealthStatus OperationalStatus SizeRemaining     Size
	----------- ------------ -------------- --------- ------------ ----------------- -------------     ----
	E           RECOVERY     FAT32          Removable Healthy      OK                      24.7 GB 31.99 GB


	Enter 'Yes' to reinitialize this Recovery Drive (E:), anything else to continue:
	Updating drive E: with OEM drivers from this system.


		Directory: E:\


	Mode          LastWriteTime Length Name
	----          ------------- ------ ----
	d----- 2024-01-31   3:01 PM        Drivers

	WARNING: Skipping E:\Drivers\en-GB\PnPUtil.exe.mui
	Microsoft PnP Utility

	Exporting driver package:   oem1.inf (backupreaderdriver.inf)
	Driver package exported successfully.

	Exporting driver package:   oem0.inf (usbaapl64.inf)
	Driver package exported successfully.

	Exporting driver package:   oem5.inf (vhusb3hc.inf)
	Driver package exported successfully.

	Exporting driver package:   oem2.inf (netaapl64.inf)
	Driver package exported successfully.

	Exporting driver package:   oem4.inf (prnms001.inf)
	Driver package exported successfully.

	Exporting driver package:   oem3.inf (prnms009.inf)
	Driver package exported successfully.

	Total driver packages:      6
	Exported driver packages:   6
	WARNING: These drivers are probably useless in the Windows PE environment:
	WARNING:   @{Driver=E:\Drivers\prnms001.inf_amd64_cf4b76d3d4b6330c; Class=PRINTER}
	WARNING:   @{Driver=E:\Drivers\prnms009.inf_amd64_3107874c7db0aa5a; Class=PRINTER}
	Enter 'Yes' to remove these drivers, anything else to continue: Yes

	Available OEM drivers on this recovery media:
	---------------------------------------------


		Directory: E:\Drivers


	Mode          LastWriteTime Length Name
	----          ------------- ------ ----
	d----- 2024-01-31   3:01 PM        en-US
	d----- 2024-01-31   3:01 PM        en-GB



	Name                                          LastWriteTime
	----                                          -------------
	backupreaderdriver.inf_amd64_6d9ee52c85e3cad1 2024-01-31 3:01:00 PM
	en-GB                                         2024-01-31 3:01:00 PM
	en-US                                         2024-01-31 3:01:00 PM
	netaapl64.inf_amd64_56f23639c9617984          2024-01-31 3:01:00 PM
	usbaapl64.inf_amd64_c0e4d8c2aef471b7          2024-01-31 3:01:00 PM
	vhusb3hc.inf_amd64_956cd640c9138cd4           2024-01-31 3:01:00 PM



	Done!

```

