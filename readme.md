# Octavi IFR-1 Script for X-Plane 12 and FlyWithLua
This script allows the use of the Octavi IFR-1 device with the Linux version of X-Plane through the use of the FlyWithLua plugin.  

_Note: For Windows-based installations of X-Plane, there are other plugins available for the Octavi IFR-1 device.  See the Octavi website for more information._

### Requirements
The following must be installed and working properly. For information about installation and configuration, please refer to their respective websites.  
* X-Plane 12.x (https://www.x-plane.com/)  
* FlyWithLua (https://github.com/X-Friese/FlyWithLua)  
* Octavi IFR-1 (https://www.octavi.net/)

### Installation of this script
To install this script, copy all files in the src directory to the XPLANE_BASE_DIRECTORY/Resources/plugins/FlyWithLua/Scripts directory.

### Configuration of the Octavi IFR-1 device
In order for this script to locate the Octavi IFR-1 device, you must do the following:
1. If the Octavi IFR-1 device is attached, disconnect it.
2. Create udev device rule for the device by running
```bash
echo "SUBSYSTEM==\"hidraw\", ATTRS{idProduct}==\"e6d6\", ATTRS{idVendor}==\"04d8\", MODE=\"0777\"" | sudo tee /etc/udev/rules.d/99-my-hid-device.rules
```
3. Force Linux to reload the rules by running
```bash
sudo udevadm control --reload-rules
```
4. Connect the Octavi IFR-1 device.

### Using the Octavi IFR-1 device
For information about how to use the Octavi IFR-1 device, please refer to their website.  

But, a brief explanation of how to use the device is below.

#### Contexts
The 8 keys in the center of the device (COM1, COM2, NAV1, NAV2, FMS1, FMS2, AP, and XPDR) allow you to choose the context of the device.  There are also additional contexts in blue above some of the keys, labelled HDG , BARO, CRS1, CRS2, and MODE.  

The "context" of the device is what system is currently being controlled by the device.  So, for example, if you wanted to control autopilot functions of the aircraft, you would press the AP button.  

The active context is illuminated.  

Not every aircraft will have every system represented by the contexts.


##### COM1 and COM2
These control the COM1 and COM2 radios.  When either of these buttons are selected, rotate the inner and outer knobs to choose the desired frequency.  To swap the active and standby frequencies, press the <--> (swap) button below the knobs.

##### NAV1 and NAV2
These control the NAV1 and NAV2 radios.  When either of these buttons are selected, rotate the inner and outer knobs to choose the desired frequency.  To swap the active and standby frequencies, press the <--> (swap) button below the knobs.

##### FMS1 and FMS2
These control the flight management systems.  Depending on the aircraft, FMS1 represents the pilot or primary flight management screen, and FMS2 represents the copilot or right flight management screen.    
When one of these is active, the action buttons along the right-side of the IFR-1, and the blue-labeled functions along the bottom of the IFR-1 can be used to control the flight management system.

##### AP
This button controls the autopilot system.  When this is selected, the white-labeled action buttons along the bottom of the IFR-1 device can be used to control the autopilot.  
Functions like altitude and VS can be adjusted using the inner and outer knobs.  
VPATH can be armed by pressing the inner knob switch.  
FLC can be selected by pressing the <--> (swap) button beneath the knobs.

##### XPDR
This button controls the transponder code.  When this is selected, use the inner and outer knobs to change the squawk code.

##### HDG
_To activate this button, first press the COM1 button. Then, press down on the inner knob button.  This activates the HDG feature of this button.  You will see a small 'HDG' indicator on-screen in the bottom-right corner for a few seconds._
This button controls the heading while navigating. Use the inner and outer knobs to adjust the heading. 

##### BARO
_To activate this button, first press the COM2 button. Then, press down on the inner knob button.  This activates the BARO feature of this button.  You will see a small 'BARO' indicator on-screen in the bottom-right corner for a few seconds._
This button controls the barometer/altimeter setting. Use the inner and outer knobs to adjust the barometer value.

##### CRS1 and CRS2
_To activate this button, first press the NAV1 or NAV2 button. Then, press down on the inner knob button.  This activates the CRS1 or CRS2 feature of this button.  You will see a small 'CRSx' indicator on-screen in the bottom-right corner for a few seconds._

##### MODE
_To activate this button, first press the XPDR button. Then, press down on the inner knob button.  This activates the MODE feature of this button.  You will see a small 'MODE' indicator on-screen in the bottom-right corner for a few seconds._
This button controls the transponder mode.      

Use the inner and outer knobs to change the transponder mode.



### Attributions

This script was originally created through reverse engineering and the guidance of sample scripts provided by Octavi.
For more information about the Octavi IFR-1, please visit https://octavi.net.

This project is not affiliated with or supported by Octavi. This is a community effort.