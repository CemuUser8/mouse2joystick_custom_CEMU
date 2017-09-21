# Script last updated on September 21, 2017.

&nbsp;

***
# Initial Setup
***
1. Install the latest [vJoy](https://sourceforge.net/projects/vjoystick/files/latest/download) 
2. Run the [vJoy Configuration](http://i.imgur.com/vvHW0yz.png) 
	* Set it up so it has **at least 18 Buttons**, I set mine to 32.
3. 	[Download controller profiles](https://bitbucket.org/CemuUser8/files/downloads/vJoyControllerProfiles.zip)  for CEMU > 1.9.0   &nbsp;&nbsp;&nbsp;&nbsp; *(Also included in GitHub release zip)*
	* Extract these text files into your [CEMU controllerProfiles folder](http://i.imgur.com/goq6zIZ.png)
	* As of Version 0.3.0.0 of the script (09/21/17) these have changed to fix the axis for both movement and camera, so please update or you will have inverted controls for moving and aiming.
4. Then open CEMU and goto the [input settings](http://i.imgur.com/N5Nibtq.png)
	* Choose the type of controller you want to use, [either 'Wii U Pro Controller' or 'Wii U GamePad'](http://i.imgur.com/sfKWlgu.png)
	* Choose [DirectInput for the Controller API](http://i.imgur.com/KKCLqs8.png)
	* Make sure to [choose the device as `vJoy Device` and confirm it says connected](http://i.imgur.com/Zx9pTmK.png)
		*  *Not sure if necessary* but [Press Calibrate](http://i.imgur.com/3E6UrZX.png)
	* Choose the [appropriate Profile](http://i.imgur.com/nH7S3U7.png) for the type of controller you are setting up.
	* [Click Load](http://i.imgur.com/PQFlfr1.png)

The input setup should look [like this](http://i.imgur.com/SvBR4BN.png), the important part is that each button be mapped in order as `Button #`

### If it doesn't look like this, you are going to have a problem

***
# Using the Script and changing the key mapping
***
1. Visit the [GitHub release page](https://github.com/CemuUser8/mouse2joystick_custom_CEMU/releases) and download the latest release (0.3.0.0 currently)
2. Launch the script:
	* Double click the `.ahk` file if you have AutoHotKey installed.
	* Run the exe if you don't.
3. IF you don't want to customize anything you are ready to use the Script.
	* Press `F1` to toggle the controller ( CEMU and Script must be running )

**Mapping your keys**

* Goto the [Mouse2Joystick->Keys](http://i.imgur.com/eMMnEGj.png) page:
	* You can set the [KeyList](http://i.imgur.com/JSJ1KsH.png) here 
		* This is a comma separated list of [AHK valid keys](https://autohotkey.com/docs/KeyList.htm) in order of vJoy Buttons
			* The first key is mapped to `Button 0` and so on.
		* Manually setting the list has an advantage in that you can add more than one key to the same button (New as of 0.2.0.3)
			* This is accomplished by adding the keys together using the `|` symbol.
				* i.e. you'll notice `Xbutton1|e,` is what I have set for `A` -- allowing `Mouse4` and `e` to both work.
		* I recommend setting up the keys with the Helper as below, then adding in any desired secondary keys manually.
	* [KeyList Helper](http://i.imgur.com/VF2vwfE.png)
		* This is an [interface that closely matches CEMU input layout](http://i.imgur.com/ewQL8ff.png), which will make it easy to create your KeyList.
		* You just need to click each box and then press the key you would like to use
			* Can be mouse buttons
		* AutoCycle will go through each key one by one allowing you to quickly set the keys
		* When you click save you will see the KeyList string update itself with any changes you've made.
			* If you'd like to add secondary keys now is a great time to do it.

Note: you can still keep KeyList strings for different games saved to a text file locally, and just paste it in (like it used to have to be done)

## Notes for 1.9.1
* There is some built-in Deadzone in CEMU for DInput devices that even when set 0 is still present (around 10% it seems)
	* This causes the camera movement to be jerky, and precise aiming is a giant pain
* The Deadzone sliders are reversed under the sticks, meaning the left slider affects the camera instead of the right one
	* This is un-intuitive and a bug most likely.

Currently the best settings I've found to *HELP* alleviate the issue is as [pictured here.](http://i.imgur.com/9DnHmW6.png)

Hopefully in 1.9.2 this will be resolved, and I will keep this section of the guide updated until it is.

### New in Version 0.3.0.0 of the script.
 You can now alternatively have the script use a virtual XBox controller instead of DInput, this eliminates the deadzone issue as it isn't present for XInput devices. Or instead enable BotW motion aim (granted this is only a specific game fix instead of a general fix)

* Make sure you've downloaded the latest version of the script (at least version listed above)
* Open your settings.ini file and either [create or change the value of your chosen option to a 1](https://i.imgur.com/6iTussf.png).
	* `usevXBox=1 OR BotWmotionAim=1`
	* The BotW motion aim does nothing when using vXbox
* After enabling either feature reload the script
	* Either re-run, or right click the icon and choose reload from the menu
* If it is the first time you are running the script using vXBox it will most likely need to install ScpVBus
	* A Message Box will pop up
		* if you press yes a prompt to run Devcon will appear, press yes
		* If you press no, vXBox will be disabled for this run
	* The script will reload and if successful the message box will not re-appear.
	* Set up CEMU input settings similar to the guide at the top except
		* Pick XInput
		* Choose the virtual XBox controller
		* Load the appropriate vXBox controller profile for your chosen controller type (included in the download)

I will work on advancing this option, and once ready I will add it to the Settings GUI, and re-make the main guide for the option, for now I am considering it an Advanced (hidden) option, and will expect users to know a bit about what they are doing with my script. That doesn't mean I won't support users trying this feature out, but I will most likely ask for steps already attempted.


***

**Other Settings Overview**

* Open the script settings by right clicking on the [controller icon in your system tray](http://i.imgur.com/fPBWOsU.png) (Bottom Right) and choose 'settings'
	* On the [General](http://i.imgur.com/hmMxz21.png) page:
		* Input Destination
			* If you changed the name of your cemu executable enter it here
		* Activate Executable
			* Choose to have the script automatically activate cemu when controller is toggled on
		* vJoy Device
			* Choose which vJoy device to control, if you have more than one set up.
	* On the [General->Setup](http://i.imgur.com/ROm9GO4.png) page:
		* Sensitivity
			* Controls how far the mouse needs to move to tilt the stick
			* Lower values are more sensitive, I recommend 30-100
		* Non-Linear Sensitivity
			* Lower values cause the sensitivity to be raised near the center
		* Deadzone
			* Can be set very close to 0, I recommend setting to the smallest possible value where your camera doesn't wander.
		* Mouse Check Frequency
			* This is how often the mouse position is checked and reset back to the center.
	* On the [General->Hotkeys](http://i.imgur.com/fkbmOvP.png) page:
		* Quit Application
			* A Master Hotkey to quit out of the script immediately
		* Toggle the controller on/off
			* Set the key to choose the Toggle for the controller (Default F1)
	* On the [Mouse2Joystick->Axes](http://i.imgur.com/EEiTuJM.png) page:
		* Invert Axis, is self explanatory
			* Apparently I initally mapped my y-axis as inverted, so 'Yes' here means 'No' (Sorry)
	*  On the [Mouse2Joystick->Keys](http://i.imgur.com/eMMnEGj.png) page:
		*  This is the Most important page as it is where you change your assigned keys
			*  **Covered in more detail above**
	*  On the [KeyboardMovement->Keys](http://i.imgur.com/okKlFwE.png) page:
		*  Keyboard Movement
			*  Set your movement keys here.
		*  Extra Keyboard Keys
			*  Set your Toggle Walk, ZL Lock, Gyro keys here
	* On the [Extra Settings](http://i.imgur.com/FvFEeVQ.png) page:
		* Enable BotW MouseWheel Weapon Change Feature
			* Choose yes if you would like to be able to use the mouse wheel to change weapons in BotW
				* Should be off for all other games obviously
		* Enable ZL Lock Key Feature
			* Also for BotW, will allow you use a separate key to toggle ZL On, until pressed again.
				* Pressing the regularily assigned ZL key will always toggle from current state
		* Cursor
			* Choose if you would like cursor hidden
				* Sometimes useful for troubleshooting to make it visible again.


***
# Script Downloads
***
**[GitHub Releases](https://github.com/CemuUser8/mouse2joystick_custom_CEMU/releases) will be the best place to find the latest version of the script** 


**[Alternate Direct Download](https://bitbucket.org/CemuUser8/files/downloads/mouse2joystick_Custom_CEMU.zip)**

***
# Extra Reminders
***

* **Changing your keys within CEMU isn't recommended as it is tedious and finicky. The script allows you to easily change which key is assigned to which vJoy button. Then the button assignment in CEMU doesn't matter at all as long as each key has something.**



* **Note that the in-game camera settings affect the camera speed the most, so try changing there if camera speed is your only issue.**

* **If you run CEMU as an admin, then you need to run the script as an admin as well.**

***
***Please feel free to comment here for help, or send me a PM.***
