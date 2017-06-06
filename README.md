# mouse2joystick_custom_CEMU
I've decided to combine my customizations into a single script to be easier to manage.


[Original Reddit Post is located here](https://www.reddit.com/r/cemu/comments/5zn0xa/autohotkey_script_to_use_mouse_for_camera/)

&nbsp;

Copy Pasted from there:

## You still must install [vJoy](https://sourceforge.net/projects/vjoystick/files/latest/download) in order for this to work, however you no longer need to install [AutoHotkey](https://autohotkey.com/download/ahk-install.exe) unless you download the non-compiled version.
***
# Initial Setup
***
* After you install vJoy you must run the [vJoy Configuration](http://i.imgur.com/5YBbtgA.png) and set it up so it has at least 17 Buttons, as you can see I set 32.

&nbsp;

* Then open CEMU and goto the input settings.
* Choose the type of controller you want to use, either 'Pro' or 'GamePad'.
* Make sure to choose the device as vJoy.
* Now you can import the layouts I've included, the 'ccc' files in the zip.  I've exported and included layouts for both GamePad and Pro controller.
* The input setup should look [like this](http://i.imgur.com/zJlASOK.png), if you chose 'Pro' it should be the same, but there won't be a 'blow mic' button.
  * Note the device is set to **vJoy NOT Keyboard**.

### If it doesn't look like this, you are going to have a problem, and you can try the following to fix the issue at this step:

- [Check this comment](https://www.reddit.com/r/cemu/comments/5zn0xa/autohotkey_script_to_use_mouse_for_camera/dgnq6lj/) for a guide on how to manually map the keys if you have import issues. Thank you /u/tacochops!

- Also you can try [running this script](https://bitbucket.org/CemuUser8/files/downloads/CEMU_Auto_vJoy_Mapper.zip) I made for auto re-mapping vJoy in the Input settings. It will ask you to open CEMU input settings, then ask you to set the device to vJoy if it isn't already, then let you know the detected type of controller (GamePad or Pro) and then automatically click through and set the buttons to the same as what the 'ccc' file should've imported. I've tested this over and over on my machine and it works, however so does importing the 'ccc' file, so who knows it might not work either.
**You must close the main script as it interferes with the mapping**

&nbsp;

&nbsp;

***
# Using the Script and changing the key mapping
***
##
At this point the script should work with the default keys and options I had set. However I recommend you customize the keys and sensitivity settings to your personal preference. 

* Press `F1` to toggle activation when running. It should automatically move the mouse and capture it to control the camera, if CEMU isn't running you will probably get an error pop-up. This key can be changed under ['General->Hotkeys'](http://i.imgur.com/DgQfU1n.png)

&nbsp;

* You open the script settings by right clicking on the [controller icon in your system tray](http://i.imgur.com/gYsabLx.png) (Bottom Right) and choosing 'settings'

&nbsp;

* To change your movement keys open script settings, and set the Keys under ['KeyboardMovement->Keys'](http://i.imgur.com/4NMjrRA.png), this is also where the toggle to walk key is set.

&nbsp;

You can change your key mappings by following these instructions:

* You goto the KeyList page and press the KeyList Helper Button located on [Mouse2JoyStick>Keys page](http://i.imgur.com/JyzT21Q.png)
* You will then see an updated version of [this screen come up,](http://i.imgur.com/hdavP22.png) I've done my best to make it look like CEMU's Input settings so it should look familiar.
	* [Example of Manually Clicking Through](https://gfycat.com/ArtisticDelayedDwarfrabbit)
	* [Example of Auto Cycling Through](https://gfycat.com/FinishedUglyHummingbird)
* When you click save you will see the KeyList string update itself with any changes you've made.

That's it, when you click OK on the main settings screen, your keys are now mapped how you have set.

* Note you can still keep KeyList strings for different games saved to a text file locally and just paste it in (like it used to have to be done)
	* I may even consider keeping an array of game layouts internally (No promises though)
