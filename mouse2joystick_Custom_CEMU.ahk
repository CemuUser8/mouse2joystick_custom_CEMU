;	;	;	;	;	;	;	;	;	;	;	;	;	;	;	;
;	Modified for CEMU by: CemuUser8 (https://www.reddit.com/r/cemu/comments/5zn0xa/autohotkey_script_to_use_mouse_for_camera/)
;	Last Modified Date: 2017-06-02
; 
;	Original Author: Helgef
;	Date: 2016-08-17
;
;	Description:
;	Mouse to keyboard or virtual joystick. For virtual joystick you need to install vJoy. See url below.
;	
;	Notes: 	
;			-#q exit at any time.
;
;	Urls:
;			https://autohotkey.com/boards/viewtopic.php?f=19&t=21489 										- First released here / help / instruction / bug reports.
;			http://vjoystick.sourceforge.net/site/															- vJoy device drivers, needed for mouse to virtual joystick.
;			https://autohotkey.com/boards/viewtopic.php?f=19&t=20703&sid=2619d57dcbb0796e16ea172f238f08a0 	- Original request by crisangelfan.
;			https://autohotkey.com/boards/viewtopic.php?t=5705												- CvJoyInterface.ahk
;
;	Acknowledgements:
;			crisangelfan and evilC on autohotkey.com forum provided useful input.
;			Credit to author(s) of vJoy @ http://vjoystick.sourceforge.net/site/
;			evilC did the CvJoyInterface.ahk
;
version := "v0.2.0.4"
#NoEnv  																; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input															; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  											; Ensures a consistent starting directory.
#Include CvJI/CvJoyInterface.ahk										; Credit to evilC.
; Settings
#MaxHotkeysPerInterval 210
#HotkeyInterval 1000
#InstallMouseHook
#SingleInstance Force
CoordMode,Mouse,Screen
SetMouseDelay,-1
SetBatchLines,-1
; On exit
OnExit("exitFunc")
toggle:=1													; On/off parameter for the hotkey.	Toggle 0 means controller is on. The placement of this variable is disturbing.
; Icon
Menu,Tray,Tip, mouse2joystick Customized for CEMU
Menu,Tray,NoStandard

IF (A_OSVersion < "10.0.15063") ; It appears that the Icon has changed number on the newest versions of Windows.
	useIcon := 26
Else
	useIcon := 27

try
	Menu,Tray,Icon,ddores.dll, %useIcon% 
;Menu,Settings,openSettings
Menu,Tray,Add,Settings,openSettings
Menu,Tray,Add,
Menu,Tray,Add,Reset to CEMU, selectGameMenu
Menu,Tray,Add
Menu,Tray,Add,About,aboutMenu
Menu,Tray,Add,Help,helpMenu
Menu,Tray,Add
Menu,Tray,Add,Reload,reloadMenu
Menu,Tray,Add,Exit,exitFunc
Menu,Tray,Default, Settings

; If no settings file, create, When changing this, remember to make corresponding changes after the setSettingsToDefault label (error handling) ; Currently at bottom of script
IfNotExist, settings.ini
{
	defaultSettings=
(
[General]
gameExe=Cemu.exe
mouse2joystick=1
autoActivateGame=1
firstRun=1
vJoyDevice=1
[General>Setup]
r=40
k=0.02
freq=25
nnp=.55
[General>Hotkeys]
controllerSwitchKey=F1
exitKey=#q
[Mouse2Joystick>Axes]
angularDeadZone=0
invertedX=0
invertedY=1
[Mouse2Joystick>Keys]
joystickButtonKeyList=e,LShift,Space,LButton,1,3,LCtrl,RButton,Enter,m,q,c,i,k,j,l,b
autoHoldStickKey=
fixRadiusKey=
[KeyboardMovement>Keys]
upKey=w
downKey=s
leftKey=a
rightKey=d
walkToggleKey=Numpad0
lockZLToggleKey=Numpad1
gyroToggleKey=v
[Extra Settings]
hideCursor=1
BotWmouseWheel=0
lockZL=0
nnVA=1
)
	FileAppend,%defaultSettings%,settings.ini
	If ErrorLevel
	{
		Msgbox,% 6+16,Error writing to file., There was a problem creating settings.ini
		, make sure you have permission to write to file at %A_ScriptDir%. If the problem persists`, try to run as administrator or change the script directory. Press retry to try again`, continue to set all settings to default or cancel to exit application.
		IfMsgBox Retry
			reload
		Else IfMsgBox Continue
			Goto, setSettingsToDefault	; Currently at bottom of script
		Else 
			ExitApp
	}
}

; Read settings.
IniRead,allSections,settings.ini
If (!allSections || allSections="ERROR") ; Do not think this is ever set to ERROR.
{
	MsgBox, % 2+16, Error reading file, There was an error reading the settings.ini file`, press retry to try again`, continue to set all settings to default or cancel to exit application.
	IfMsgBox retry
		reload
	Else IfMsgBox Ignore
		Goto, setSettingsToDefault	; Currently at bottom of script
	Else 
		ExitApp
}
Loop,Parse,allSections,`n
{
	IniRead,pairs,settings.ini,%A_LoopField%
	Loop,Parse,pairs,`n
	{
		StringSplit,keyValue,A_LoopField,=
		%keyValue1%:=keyValue2
	}
}
readSettingsSkippedDueToError:	; This comes from setSettingsToDefault If there was an error.

pi:=atan(1)*4													; Approx pi.
angularDeadZone*=pi/180											; Convert to radians
angularDeadZone:=angularDeadZone>pi/4 ? pi/4:angularDeadZone	; Ensure correct range

; Constants and such. Some values are commented out because they have been stored in the settings.ini file instead, but are kept because they have comments.
moveStickHalf := False
KeyList := []
KeyListByNum := []

dr:=0											; Bounce back when hit outer circle edge, in pixels. (This might not work any more, it is off) Can be seen as a force feedback parameter, can be extended to depend on the over extension beyond the outer ring.

; Hotkey(s).
Hotkey,%controllerSwitchKey%,controllerSwitch, on
Hotkey,%exitKey%,exitFunc, on

mouse2joystick := True
If mouse2joystick
{
	Gosub, initCvJoyInterface
	Gosub, mouse2joystickHotkeys
}

IF freq is not Integer
	freq := 25

pmX:=invertedX ? -1:1							; Sign for inverting axis
pmY:=invertedY ? -1:1
snapToFullTilt:=0.005							; This needs to be improved.
fr:=0											; Fixed radius.
;nnp:=4	 										; Non-linearity parameter for joystick output, 1 = linear, >1 higher sensitivity closer to full tilt, <1 higher sensitivity closer to deadzone. Recommended range, [0.1,6]. 
; New parameters
stickIsAutoHeld:=0								; Tracks the status of autohold stick. 0 means it is not being auto held.

segmentEndAngles:=Object()						; Each segment is defined by its angle, segment 1,...,12 -> end angle pi/6,pi/3,...,2*pi [rad]. (Unfortuantley its clockwise, with 0/2pi being at three o'clock)
Loop,12
	segmentEndAngles[A_Index]:=pi/6*A_Index

; Mouse blocker
; Transparent window that covers game screen to prevent game from capture the mouse.
Gui, Controller: New
Gui, Controller: +ToolWindow -Caption +AlwaysOnTop +HWNDstick
Gui, Controller: Color, FFFFFF

; Spam user with useless info, first time script runs.
If (firstRun)
{
	MsgBox,64,Welcome,Settings are accessed via Tray icon -> Settings.
	IniWrite,0,settings.ini,General,firstRun
}

Return
; End autoexec.

selectGameMenu:
	TrayTip, % "Game reset to cemu.exe", % "If you want something different manually edit the settings, or 'settings.ini' file directly",,0x10
	gameExe := "cemu.exe"
	IniWrite, %gameExe%, settings.ini, General, gameExe
Return

reloadMenu:
	Reload
Return

aboutMenu:
	Msgbox,32,About, Modified for CEMU by:`nCemuUser8`n`nVersion:`n%version%
Return

helpMenu:
	Msgbox,% 4+ 32 , Open help in browser?, Visit Reddit post on /r/cemu for help?`n`nIt is helpful to know the version (%version%)`nand If possible a pastebin of your 'settings.ini' file will help me troubleshoot.`n`nWill Open link in default browser.
	IfMsgBox Yes
		Run, https://www.reddit.com/r/cemu/comments/5zn0xa/autohotkey_script_to_use_mouse_for_camera/
Return


initCvJoyInterface:
	; Copied from joytest.ahk, from CvJoyInterface by evilC
	; Create an object from vJoy Interface Class.
	vJoyInterface := new CvJoyInterface()
	; Was vJoy installed and the DLL Loaded?
	If (!vJoyInterface.vJoyEnabled()){
		; Show log of what happened
		Msgbox,% 4+16,vJoy Error,% "vJoy needs to be installed. Press no to exit application.`nLog:`n" . vJoyInterface.LoadLibraryLog ; Error handling changed.
		IfMsgBox Yes
		{
			;IniWrite, 0,settings.ini,General,mouse2joystick
			reload
		}
		ExitApp
	}
	ValidDevices := ""
	Loop 15
	{
		IF (vJoyInterface.Devices[A_Index].IsAvailable())
			ValidDevices .= A_Index . "|"
	}
	Global vstick := vJoyInterface.Devices[vJoyDevice]
Return

; Hotkey labels
; This switches on/off the controller.
controllerSwitch:
	If toggle	; Starting controller
	{
		If autoActivateGame
		{
			WinActivate,ahk_exe %gameExe%
			WinWaitActive, ahk_exe %gameExe%,,2
			If ErrorLevel	
			{
				MsgBox,16,Error, %gameExe% not activated.
				Return
			}
			WinGetPos,gameX,gameY,gameW,gameH,ahk_exe %gameExe%									; Get game screen position and dimensions
		}
		Else
		{
			gameX:=0
			gameY:=0
			gameW:=A_ScreenWidth
			gameH:=A_ScreenHeight
		}
		DllCall("User32.dll\ReleaseCapture")													; Release mouse capture from game.
		
		; Controller origin is center of game screen or screen If autoActivateGame:=0.
		OX:=gameX+gameW/2				
		OY:=gameY+gameH/2
		
		IF (!OX OR !OY) {
			OX := 500
			OY := 500
		}

		; Move mouse to controller origin
		MouseMove,OX,OY	
		
		; The mouse blocker
		Gui, Controller: Show,NA x%gameX% y%gameY% w%gameW% h%gameH%,Controller
		Gui, Controller:+LastFound
		WinSet,Transparent,1,ahk_id %stick%														; Make transparent.
		DllCall("User32.dll\SetCapture", "Uint", stick)											; Let the controller capture the mouse.
		
		If hideCursor
			DllCall("User32.dll\ShowCursor", "Int", 0)
			
		If mouse2joystick
			SetTimer,mouseTojoystick,%freq%
	}
	Else	; Shutting down controller
	{
		If mouse2joystick
		{
			SetTimer,mouseTojoystick,Off
			setStick(0,0)															; Stick in equllibrium.
			setStick(0,0, True)
		}			
		
		If hideCursor
			DllCall("User32.dll\ShowCursor", "Int", 1) 							; No need to show cursor if not hidden.

		DllCall("User32.dll\ReleaseCapture")									; This might be unnecessary
		stickIsAutoHeld:=0 														; Ensure stick is not being held
		WinHide, ahk_id %stick%
		
	}
	toggle:=!toggle
Return

autoHoldStick:
	;
	;	Sub-routine for enabling user to lock joystick position and use mouse normally.
	;
	If !stickIsAutoHeld
	{
		; Here the stick is not being auto held and user wants to auto hold it.
		If hideCursor
			DllCall("User32.dll\ShowCursor", "Int", 1) 						; Show cursor
		
		
		
		WinHide, ahk_id %stick%
		DllCall("User32.dll\ReleaseCapture")	
		
		MouseGetPos,ahX,ahY													; Save mouse position
		MouseMove,OX,OY														; Move mouse
		If mouse2joystick
			SetTimer, mouseTojoystick, Off									; Shut down timer									
	}
	Else
	{

		; Here the stick is being auto held and user wants to get back control.
		If hideCursor
			DllCall("User32.dll\ShowCursor", "Int", 0) 						; Hide cursor again		
		
		
		WinShow, ahk_id %stick%
		DllCall("User32.dll\SetCapture", "Uint", stick)						; Let the controller capture the mouse.
					
		MouseMove,ahX,ahY													; Move back mouse.
		If mouse2joystick
			SetTimer, mouseTojoystick, on									; Turn timer back on.
	}
	stickIsAutoHeld:=!stickIsAutoHeld										; Toggle auto hold status
Return

; Hotkeys mouse2joystick
#If (!toggle && mouse2joystick)
#If
mouse2joystickHotkeys:
	Hotkey, If, (!toggle && mouse2joystick)
		SetStick(0,0, True)
		IF (walkToggleKey)
			HotKey,%walkToggleKey%,toggleHalf, On
		IF (lockZLToggleKey AND lockZL)
			HotKey,%lockZLToggleKey%,toggleAimLock, On
		IF (BotWmouseWheel) {
			Hotkey,WheelUp, overwriteWheelUp, on
			Hotkey,WheelDown, overwriteWheelDown, on
		}
		IF (gyroToggleKey) {
			HotKey,%gyroToggleKey%, GyroControl, on
			HotKey,%gyroToggleKey% Up, GyroControlOff, on
		}
		Hotkey,%upKey%, overwriteUp, on 
		Hotkey,%upKey% Up, overwriteUpup, on
		Hotkey,%leftKey%, overwriteLeft, on 
		Hotkey,%leftKey% Up, overwriteLeftup, on
		Hotkey,%downKey%, overwriteDown, on 
		Hotkey,%downKey% Up, overwriteDownup, on
		Hotkey,%rightKey%, overwriteRight, on 
		Hotkey,%rightKey% Up, overwriteRightup, on
	KeyList := []
	Loop, Parse, joystickButtonKeyList, `,
	{
		useButton := A_Index
		Loop, Parse, A_LoopField, |
		{		
			keyName:=A_LoopField
			If !keyName
				continue
			KeyList[keyName] := useButton
			Hotkey,%keyName%, pressJoyButton, on 
			Hotkey,%keyName% Up, releaseJoyButton, on
		}
	}
	If autoHoldStickKey
		HotKey, %autoHoldStickKey%, autoHoldStick, On
	If fixRadiusKey
		HotKey, %fixRadiusKey%, fixRadius, On
	Hotkey, If
Return

fixRadius:
	If fr										; Toggle fixed/free.
	{
		fr:=0
		Return
	}
	MouseGetPos,X,Y
	X-=OX										; Move to controller coord system.
	Y-=OY
	fr:=sqrt(X**2+Y**2) 						; Fix radius to current deflection.
Return


; Labels for pressing and releasing joystick buttons.
pressJoyButton:
	keyName:=A_ThisHotkey
	joyButtonNumber := KeyList[keyName] ; joyButtonNumber:=A_Index
	If (joyButtonNumber = 7 AND lockZL) {
		IF (ZLToggle)
			vstick.SetBtn(0,joyButtonNumber)
		Else
			vstick.SetBtn(1,joyButtonNumber)
	}
	Else If joyButtonNumber
		vstick.SetBtn(1,joyButtonNumber)
Return

releaseJoyButton:
	keyName:=RegExReplace(A_ThisHotkey," Up$")
	joyButtonNumber := KeyList[keyName] ; joyButtonNumber:=A_Index
	If (joyButtonNumber = 7 AND lockZL) {
		IF (ZLToggle)
			vstick.SetBtn(1,joyButtonNumber)
		Else
			vstick.SetBtn(0,joyButtonNumber)
	}
	Else If joyButtonNumber
		vstick.SetBtn(0,joyButtonNumber)
Return

GyroControl:
	SetTimer, mouseTojoystick, Off
	IF (BotWmouseWheel) {
		Hotkey, If, (!toggle && mouse2joystick)
		Hotkey,WheelUp, overwriteWheelUp, off
		Hotkey,WheelDown, overwriteWheelDown, off
	}
	SetStick(0,0)
	Gui, Controller:Hide
	ControlClick,, ahk_exe %gameEXE%,, R,,D

Return

GyroControlOff:
	ControlClick,, ahk_exe %gameEXE%,, R,,U
	IF (BotWmouseWheel) {
		Hotkey, If, (!toggle && mouse2joystick)
		Hotkey,WheelUp, overwriteWheelUp, on
		Hotkey,WheelDown, overwriteWheelDown, on
	}
	Gui, Controller:Show, NA
	SetTimer, mouseTojoystick, On
Return


toggleAimLock:
	vstick.SetBtn((ZLToggle := !ZLToggle),7)
Return

toggleHalf:
	moveStickHalf := !moveStickHalf
	IF (GetKeyState(downKey, "P"))
		SetStick("N/A",(moveStickHalf ? 0.5 : 1), True)
	IF (GetKeyState(rightKey, "P"))
		SetStick((moveStickHalf ? 0.5 : 1),"N/A", True)
	IF (GetKeyState(leftKey, "P"))
		SetStick((moveStickHalf ? -0.5 : -1),"N/A", True)
	IF (GetKeyState(upKey, "P"))
		SetStick("N/A",(moveStickHalf ? -0.5 : -1), True)
Return

overwriteUp:
Critical
IF (moveStickHalf)
	SetStick("N/A",-0.5, True)
Else
	SetStick("N/A",-1, True)
Return
overwriteUpup:
Critical
IF (GetKeyState(downKey, "P")) {
	IF (moveStickHalf)
		SetStick("N/A",0.5, True)
	Else
		SetStick("N/A",1, True)
}
Else
	SetStick("N/A",0, True)
Return

overwriteLeft:
Critical
IF (moveStickHalf)
	SetStick(-0.5,"N/A", True)
Else
	SetStick(-1,"N/A", True)
Return
overwriteLeftup:
Critical
IF (GetKeyState(rightKey, "P")) {
	IF (moveStickHalf)
		SetStick(0.5,"N/A", True)
	Else
		SetStick(1,"N/A", True)
}
Else
	SetStick(0,"N/A", True)
Return

overwriteRight:
Critical
IF (moveStickHalf)
	SetStick(0.5,"N/A", True)
Else
	SetStick(1,"N/A", True)
Return
overwriteRightup:
Critical
IF (GetKeyState(leftKey, "P")) {
	IF (moveStickHalf)
		SetStick(-0.5,"N/A", True)
	Else
		SetStick(-1,"N/A", True)
}
Else
	SetStick(0,"N/A", True)
Return

overwriteDown:
Critical
IF (moveStickHalf)
	SetStick("N/A",0.5, True)
Else
	SetStick("N/A",1, True)
Return
overwriteDownup:
Critical
IF (GetKeyState(upKey, "P")) {
	IF (moveStickHalf)
		SetStick("N/A",-0.5, True)
	Else
		SetStick("N/A",-1, True)
}
Else
	SetStick("N/A",0, True)
Return

overwriteWheelUp:
	SetStick(0,0)
	IF (!alreadyDown){
		vstick.SetBtn(1,16)
		alreadyDown := True
		DllCall("Sleep", Uint, 250)
	}
	SetStick(-1,0)
	DllCall("Sleep", Uint, 30)
	SetStick(0,0)
	SetTimer, ReleaseDPad, -650 ; vstick.SetBtn(0,16)
Return
overwriteWheelDown:
	SetStick(0,0)
	IF (!alreadyDown){
		vstick.SetBtn(1,16)
		alreadyDown := True
		DllCall("Sleep", Uint, 250)
	}
	SetStick(1,0)
	DllCall("Sleep", Uint, 30)
	SetStick(0,0)
	SetTimer, ReleaseDPad, -650 ; vstick.SetBtn(0,16)
Return

ReleaseDPad:
	vstick.SetBtn(0,16)
	alreadyDown := False
	SetTimer, ReleaseDPad, Off
Return

; Labels

mouseTojoystick:
	Critical
	mouse2joystick(r,dr,OX,OY)
Return

; Functions

mouse2joystick(r,dr,OX,OY)
{
	; r is the radius of the outer circle.
	; dr is a bounce back parameter.
	; OX is the x coord of circle center.
	; OY is the y coord of circle center.
	; fr is the fixed radius
	Global k, nnp, fr, AlreadyDown
	MouseGetPos,X,Y
	X-=OX										; Move to controller coord system.
	Y-=OY
	RR:=sqrt(X**2+Y**2)
	If fr										; If fixed radius.
	{
		X:=round(X*fr/RR)
		Y:=round(Y*fr/RR)
		RR:=sqrt(X**2+Y**2)
		MouseMove,X+OX,Y+OY 
	}
	Else If (RR>r)								; Check If outside controller circle.
	{
		X:=round(X*(r-dr)/RR)
		Y:=round(Y*(r-dr)/RR)
		RR:=sqrt(X**2+Y**2)
		MouseMove,X+OX,Y+OY 					; Calculate point on controller circle, move back to screen/window coords, and move mouse.
	}
	
	; Calculate angle
	phi:=getAngle(X,Y)							
	
	
	If (RR>k*r AND !AlreadyDown) 								; Check If outside inner circle/deadzone.
		action(phi,((RR-k*r)/(r-k*r))**nnp)		; nnp is a non-linearity parameter.	
	 Else
		 setStick(0,0)							; Stick in equllibrium.

	MouseMove,OX,OY
}

action(phi,tilt)
{	
	; This is for mouse2joystick.
	; phi ∈ [0,2*pi] defines in which direction the stick is tilted.
	; tilt ∈ (0,1] defines the amount of tilt. 0 is no tilt, 1 is full tilt.
	; When this is called it is already established that the deadzone is left, or the inner radius.
	; pmX/pmY is used for inverting axis.
	; snapToFullTilt is used to ensure full tilt is possible, this needs to be improved, should be dependent on the sensitivity.
	Global angularDeadZone,pmX,pmY,pi,snapToFullTilt

	; Adjust tilt
	tilt:=tilt>1 ? 1:tilt
	If (snapToFullTilt!=-1)
		tilt:=1-tilt<=snapToFullTilt ? 1:tilt
	
	; If in angular deadzone, only output to one axis is done, for easy "full tilt" in one direction without any small drift to other direction.
	; In angular deadzone, the output is "output"
	If (phi<3*pi/2+angularDeadZone && phi>3*pi/2-angularDeadZone)							; In angular deadzone for Y-axis forward tilt.
	{
		setStick(0,pmY*tilt)
		Return
	}
	If (phi<pi+angularDeadZone && phi>pi-angularDeadZone)									; In angular deadzone for X-axis left    tilt.
	{
		setStick(-pmX*tilt,0)
		Return
	}
	If (phi<pi/2+angularDeadZone && phi>pi/2-angularDeadZone)								; In angular deadzone for Y-axis down	 tilt.
	{
		setStick(0,-pmY*tilt)
		Return
	}	
	If ((phi>2*pi-angularDeadZone && phi<2*pi) || (phi<angularDeadZone && phi>=0) )			; In angular deadzone for Y-axis right	 tilt.
	{
		setStick(pmX*tilt,0)
		Return
	}
	
	; Not inside angular deadzone. Here leq and geq should be used. There are eight cases.
	
	; Two cases with forward+right
	; Tilt is forward and slightly right.
	lb:=3*pi/2+angularDeadZone						; lb is lower bound
	ub:=7*pi/4										; ub is upper bound
	If (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt*scale(phi,ub,lb)
		y:=pmY*tilt
		setStick(x,y)
		Return
	}
	; Tilt is slightly forward and right.
	lb:=7*pi/4										; lb is lower bound
	ub:=2*pi-angularDeadZone						; ub is upper bound
	If (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt
		y:=pmY*tilt*scale(phi,lb,ub)
		setStick(x,y)
		Return
	}
	
	; Two cases with right+downward
	; Tilt is right and slightly downward.
	lb:=angularDeadZone								; lb is lower bound
	ub:=pi/4										; ub is upper bound
	If (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt
		y:=-pmY*tilt*scale(phi,ub,lb)
		setStick(x,y)
		Return
	}
	; Tilt is downward and slightly right.
	lb:=pi/4										; lb is lower bound
	ub:=pi/2-angularDeadZone						; ub is upper bound
	If (phi>=lb && phi<=ub)							
	{
		x:=pmX*tilt*scale(phi,lb,ub)
		y:=-pmY*tilt
		setStick(x,y)
		Return
	}
	
	; Two cases with downward+left
	; Tilt is downward and slightly left.
	lb:=pi/2+angularDeadZone						; lb is lower bound
	ub:=3*pi/4										; ub is upper bound
	If (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt*scale(phi,ub,lb)
		y:=-pmY*tilt
		setStick(x,y)
		Return
	}
	; Tilt is left and slightly downward.
	lb:=3*pi/4										; lb is lower bound
	ub:=pi-angularDeadZone							; ub is upper bound
	If (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt
		y:=-pmY*tilt*scale(phi,lb,ub)
		setStick(x,y)
		Return
	}
	
	; Two cases with forward+left
	; Tilt is left and slightly forward.
	lb:=pi+angularDeadZone							; lb is lower bound
	ub:=5*pi/4										; ub is upper bound
	If (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt
		y:=pmY*tilt*scale(phi,ub,lb)
		setStick(x,y)
		Return
	}
	; Tilt is forward and slightly left.
	lb:=5*pi/4										; lb is lower bound
	ub:=3*pi/2-angularDeadZone						; ub is upper bound
	If (phi>=lb && phi<=ub)							
	{
		x:=-pmX*tilt*scale(phi,lb,ub)
		y:=pmY*tilt
		setStick(x,y)
		Return
	}
	; This should not happen:
	setStick(0,0)
	MsgBox,16,Error, Error at phi=%phi%. Please report.
	Return
}

scale(phi,lb,ub)
{
	; let phi->f(phi) then, f(ub)=0 and f(lb)=1
	Return (phi-ub)/(lb-ub)
}

setStick(x,y, a := False)
{
	; Set joystick x-axis to 100*x % and y-axis to 100*y %
	; Input is x,y ∈ (-1,1) where 1 would mean full tilt in one direction, and -1 in the other, while zero would mean no tilt at all. Using this interval makes it easy to invert the axis
	; (mainly this was choosen beacause the author didn't know the correct interval to use in CvJoyInterface)
	; the input is not really compatible with the CvJoyInterface. Hence this transformation:	
	x:=(x+1)*16384									; This maps x,y ∈ (-1,1) -> (0,32768)
	y:=(y+1)*16384

	; IF (!a) { ; Was alternate attempt to solution 1.9.0 introduced, but I don't like having to hard code special solutions.
		; IF (x > 16384 AND x < 20480)
			; x :=  16384 + ((x-16384)*1.16)
		; Else IF (x < 16384 AND x > 12288)
			; x := 16384 - ((16384 - x)*1.16)
		; IF (y > 16384 AND y < 20480)
			; y :=  16384 + ((y-16384)*1.16)
		; Else IF (y < 16384 AND y > 12288)
			; y := 16384 - ((16384 - y)*1.16)
	; }
	
	; Use set by index.
	; x = 1, y = 2.
	IF ( a ) { ;IF (GetKeyState("RButton") OR a ) {
		axisX := 4
		axisY := 5
	}
	Else {
		axisX := 1
		axisY := 2
	}
	IF x is number
		vstick.SetAxisByIndex(x,axisX)
	IF y is number
		vstick.SetAxisByIndex(y,axisY)
}


; Shared functions
getAngle(x,y)
{
	Global pi
	If (x=0)
		Return 3*pi/2-(y>0)*pi
	phi:=atan(y/x)
	If (x<0 && y>0)
		Return phi+pi
	If (x<0 && y<=0)
		Return phi+pi
	If (x>0 && y<0)
		Return phi+2*pi
	Return phi
}

exitFunc()
{
	Global
	If mouse2Joystick
	{
		setStick(0,0)
		SetStick(0,0, True)
		vstick.Relinquish()
	}
	
	BlockInput, MouseMoveOff
	DllCall("User32.dll\ShowCursor", "Int", 1)
	ExitApp
}

; Misc labels and such
tipOff:
	Tooltip
Return


;
; End Script.
; Start settings.
; This is auto generated.
;
openSettings:
If !toggle			; This is probably best.
	Return
Gui, Main: Destroy ; Ops
hideShow=0 
win_name := "Mouse2Joystick Custom for CEMU Settings  -  " . version
submitOnlyOne:=0 
GoSub,readTreeString
Gui, Main: -Resize
GUI, Main: add, text, x10  , Options:
Gui, Main: Add, TreeView,  vMainTreeVar r16 w150 gTreeClick
Gui, Main: Add, button, x10 w100 gmainOk ,Ok
GUI, Main: Add, StatusBar
SB_SetParts(150,50)
GoSub,guiCode
GUI, Main:+HwndMAIN_HWND
Gui, Main: Show,, %win_name%
Main_WinTitle=ahk_id %MAIN_HWND%
GuiControl, -Redraw, Main 
Gui, Main: default
TV_LoadTree(tree)
GuiControl, +Redraw, Main 
Return	
TreeClick:
	lastSection:=section
	If A_GuiEvent = S
		selection:=A_EventInfo
	section:=selectionPath(selection)		
	SB_SetText("You are in: " . section,1)	
	TV_GetText(nodeName,selection)
	If (IsLabel(lastSection))
	{
		hideShow=0
		Gosub,%lastSection%	
	}
	section:=RegExReplace(section,"[ ]+","_")		
	If (IsLabel(section))
	{
		hideShow=1
		Gosub,%section%  	 
		hideShow=0			 
	}
Return
mainOk:
	Gui, Main: Submit
	Gosub, SubmitAll
	; Get old hotkeys.
	; Disable old hotkeys
	Hotkey,%controllerSwitchKey%,controllerSwitch, off
	Hotkey,%exitKey%,exitFunc, off
		
	; Joystick buttons
	Hotkey, If, (!toggle && mouse2joystick)
	HotKey,%walkToggleKey%,toggleHalf, Off
	HotKey,%lockZLToggleKey%,toggleAimLock, Off
	Hotkey,WheelUp, overwriteWheelUp, off
	Hotkey,WheelDown, overwriteWheelDown, off
	HotKey,%gyroToggleKey%, GyroControl, off
	HotKey,%gyroToggleKey% Up, GyroControlOff, off

	Hotkey,%upKey%, overwriteUp, off
	Hotkey,%upKey% Up, overwriteUpup, off
	Hotkey,%leftKey%, overwriteLeft, off
	Hotkey,%leftKey% Up, overwriteLeftup, off
	Hotkey,%downKey%, overwriteDown, off
	Hotkey,%downKey% Up, overwriteDownup, off
	Hotkey,%rightKey%, overwriteRight, off
	Hotkey,%rightKey% Up, overwriteRightup, off

	Loop, Parse, joystickButtonKeyList, `,
	{
		useButton := A_Index
		Loop, Parse, A_LoopField, |
		{		
			keyName:=A_LoopField
			If !keyName
				continue
			KeyList[keyName] := useButton
			Hotkey,%keyName%, pressJoyButton, off
			Hotkey,%keyName% Up, releaseJoyButton, off
		}
	}
	If autoHoldStickKey
		HotKey, %autoHoldStickKey%, autoHoldStick, off
	If fixRadiusKey
		HotKey, %fixRadiusKey%, fixRadius, off
	Hotkey, If

	; Read settings.
	
	IniRead,allSections,settings.ini
	
	Loop,Parse,allSections,`n
	{
		IniRead,pairs,settings.ini,%A_LoopField%
		Loop,Parse,pairs,`n
		{
			StringSplit,keyValue,A_LoopField,=
			%keyValue1%:=keyValue2
		}
	}

	If mouse2joystick
	{
		Gosub, initCvJoyInterface
		Gosub, mouse2joystickHotkeys
	}
	pmX:=invertedX ? -1:1											; Sign for inverting axis
	pmY:=invertedY ? -1:1
	angularDeadZone*=pi/180											; Convert to radians
	angularDeadZone:=angularDeadZone>pi/4 ? pi/4:angularDeadZone	; Ensure correct range

	; Enable new hotkeys
	Hotkey,%controllerSwitchKey%,controllerSwitch, on
	Hotkey,%exitKey%,exitFunc, on
	
Return
guiCode:
Iniread,editText,settings.ini,General,gameExe
editText:=RegExReplace(editText,"DELIM_\|_ITER","`n")
Gui, Main: add, Edit,Hidden   vedit1092695107 X185 Y115 r1 w150,%editText%
editText= 
Gui, Main: add, GroupBox,Hidden vtext23478877 X170 Y25 W520 H64,Output mode
Gui, Main: add, GroupBox,Hidden vtext1153671792 X170 Y95 W520 H53,Input desitnation
Gui, Main: add, GroupBox,Hidden vtext1396826083 X170 Y155 W520 H45,Activate Executable
Gui, Main: add, GroupBox,Hidden vvJoyGroupBox X170 Y215 W520 H53,vJoy Device
Iniread,master_var,settings.ini,General,mouse2joystick
checkMe:= (master_var="1") ? 1:0
Gui, Main: Add, Radio, Hidden Section Group Checked%checkMe% vradio1244113855_1 X185 Y45, Mouse2Joystick (requires vJoy)
checkMe:= (master_var="0") ? 1:0
;Gui, Main: Add, Radio, Hidden  Checked%checkMe% vradio1244113855_2,  Mouse2Keyboard
Iniread,master_var,settings.ini,General,autoActivateGame
checkMe:= (master_var="1") ? 1:0
Gui, Main: Add, Radio, Hidden Section Group Checked%checkMe% vradio1371042200_1 X185 Y175, Yes
checkMe:= (master_var="0") ? 1:0
Gui, Main: Add, Radio, Hidden ys Checked%checkMe% vradio1371042200_2,  No
Text=	
(
The name of the executable that will receive the output.
)
Gui, Main: add, Text,Hidden vtext1439415306 X350 Y118,%Text%
Text= 
Text=	
(
Automatically activate executable  (If it is running)  when controller is switched on.
)
Gui, Main: add, Text,Hidden vtext1649409801 X285 Y175,%Text%
Text= 
Gui, Main: add, DropDownList, Hidden vvJoyDropDown Section X185 Y235, %ValidDevices%
useList := RegExReplace(ValidDevices, "(^|\|)" . vJoyDevice . "(\||$)", "$1" . vJoyDevice . "|$2")
GuiControl, Main:,vJoyDropDown, % "|" . useList
Iniread,editText,settings.ini,General>Setup,r
editText:=RegExReplace(editText,"DELIM_\|_ITER","`n")
Gui, Main: add, Edit,Hidden Number   vedit968841594 X185 Y45 r1 w75,%editText%
editText= 
Iniread,editText,settings.ini,General>Setup,k
editText:=RegExReplace(editText,"DELIM_\|_ITER","`n")
Gui, Main: add, Edit,Hidden   vedit1484171716 X185 Y165 r1 w75,%editText%
editText= 
Iniread,editText,settings.ini,General>Setup,freq
editText:=RegExReplace(editText,"DELIM_\|_ITER","`n")
IF editText is not Integer
	editText := 25
Gui, Main: add, Edit,Hidden   vedit1441011004 X185 Y225 r1 w75,%editText%
editText= 
Iniread,editText,settings.ini,General>Setup,nnp
editText:=RegExReplace(editText,"DELIM_\|_ITER","`n")
Gui, Main: add, Edit,Hidden   vedit1136845697 X185 Y105 r1 w75,%editText%
editText= 
Gui, Main: add, GroupBox,Hidden vtext1820027441 X170 Y25 W520 H53,Sensitivity
Gui, Main: add, GroupBox,Hidden vtext1761503059 X170 Y85 W520 H53,Non linear sensitivity
Gui, Main: add, GroupBox,Hidden vtext868645638 X170 Y145 W520 H53,Deadzone
Gui, Main: add, GroupBox,Hidden vtext303295627 X171 Y205 W520 H53,Mouse Check Frequency
Text=	
(
1 is linear, <1 lowers sensitivity away from center, >1 hightens sensitivity away center.
)
Gui, Main: add, Text,Hidden vtext1950133817 X270 Y109,%Text%
Text= 
Text=	
(
Range, (0,1). The center area where no output is sent.
)
Gui, Main: add, Text,Hidden vtext1365655690 X270 Y169,%Text%
Text= 
Text=	
(
ms. This should be low, I recommend trying between 9-32 Default:25
)
Gui, Main: add, Text,Hidden vtext1314749378 X270 Y227,%Text%
Text= 
Text=	
(
Range, (0,Screen Height/2). Lower values corresponds to higher sensitivity.
)
Gui, Main: add, Text,Hidden vtext68851252 X270 Y48,%Text%
Text= 
Gui, Main: add, GroupBox,Hidden vtext495210823 X170 Y25 W520 H72,Quit application
Gui, Main: add, GroupBox,Hidden vtext199783574 X170 Y105 W520 H72,Toggle the controller on/off
;Gui, Main: add, GroupBox,Hidden vtext1265532956 X170 Y185 W520 H72,Enable/disable movement of visual aid
Iniread,master_var,settings.ini,General>Hotkeys,controllerSwitchKey									
hotkey26759803_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden 0 vhotkey26759803 X185 Y125 W150,% RegExReplace(master_var,"#")
checkMe:=RegExMatch(master_var,"#") ? 1:0
Gui, Main: add, CheckBox, Hidden vhotkey26759803_addWinkey checked%checkMe%,Use modifer: Winkey
Iniread,master_var,settings.ini,General>Hotkeys,exitKey									
hotkey255211840_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden 0 vhotkey255211840 X185 Y45 W150,% RegExReplace(master_var,"#")
checkMe:=RegExMatch(master_var,"#") ? 1:0
Gui, Main: add, CheckBox, Hidden vhotkey255211840_addWinkey checked%checkMe%,Use modifer: Winkey
Text=	
(
There is no input verification.
Follow instructions and don't try to break it.
)
Gui, Main: add, Text,Hidden vtext938990667 X170 Y25,%Text%
Text= 
Iniread,editText,settings.ini,Mouse2Joystick>Axes,angularDeadZone
editText:=RegExReplace(editText,"DELIM_\|_ITER","`n")
Gui, Main: add, Edit,Hidden Number  Limit2 vedit446078763 X185 Y155 r1 w75,%editText%
editText= 
Gui, Main: add, GroupBox,Hidden vtext1772933493 X170 Y35 W520 H45,Invert X-axis
Gui, Main: add, GroupBox,Hidden vtext11683084 X170 Y85 W520 H45,Invert Y-axis
Gui, Main: add, GroupBox,Hidden vtext1550313039 X170 Y135 W520 H53,Angular deadzone
Iniread,master_var,settings.ini,Mouse2Joystick>Axes,invertedX
checkMe:= (master_var="1") ? 1:0
Gui, Main: Add, Radio, Hidden Section Group Checked%checkMe% vradio1025876589_1 X185 Y55, Yes
checkMe:= (master_var="0") ? 1:0
Gui, Main: Add, Radio, Hidden ys Checked%checkMe% vradio1025876589_2,  No
Iniread,master_var,settings.ini,Mouse2Joystick>Axes,invertedY
checkMe:= (master_var="1") ? 1:0
Gui, Main: Add, Radio, Hidden Section Group Checked%checkMe% vradio122217493_1 X185 Y105, Yes
checkMe:= (master_var="0") ? 1:0
Gui, Main: Add, Radio, Hidden ys Checked%checkMe% vradio122217493_2,  No
Text=	
(
Range: [0,45]. Defines the area where only one axis is used.
)
Gui, Main: add, Text,Hidden vtext374447714 X275 Y159,%Text%
Text= 
Iniread,editText,settings.ini,Mouse2Joystick>Keys,joystickButtonKeyList
editText:=RegExReplace(editText,"DELIM_\|_ITER","`n")
Gui, Main: add, Edit,Hidden -Wrap   vedit1874406880 X185 Y50 r1 w475,%editText%
editText= 
;Gui, Main: add, GroupBox,Hidden vtext906325482 X170 Y25 W520 H88,Keylist
;Gui, Main: add, GroupBox,Hidden vtext1019731688 X170 Y125 W520 H92,Hotkeys
;Iniread,master_var,settings.ini,Mouse2Joystick>Keys,autoHoldStickKey									
;hotkey932981360_oldkey:=master_var															
;Gui, Main: add, Hotkey, Hidden 0 vhotkey932981360 X185 Y165 W150,% RegExReplace(master_var,"#")
;checkMe:=RegExMatch(master_var,"#") ? 1:0
;Gui, Main: add, CheckBox, Hidden vhotkey932981360_addWinkey checked%checkMe%,Use modifer: Winkey

;Iniread,master_var,settings.ini,Mouse2Joystick>Keys,fixRadiusKey																					
;Gui, Main: add, Hotkey, Hidden 0 vhotkey93298136 X355 Y165 W150,% RegExReplace(master_var,"#")
;checkMe:=RegExMatch(master_var,"#") ? 1:0
;Gui, Main: add, CheckBox, Hidden vhotkey93298136_addWinkey checked%checkMe%,Use modifer: Winkey

GUI, Main: Add, Button, Hidden vKeyListHelperButton gKeyListHelper x185 y150 r1 w475 Center, KeyList Helper
Text=	
(
The key list is a comma delimited list of (ahk valid) keys, where each entry binds to a joystick button.
The first entry binds to the first joystick buttons, and so on. Blanks and modifiers are allowed.
)
Gui, Main: add, Text,Hidden vtext789866609 X185 Y80,%Text%
Text= 
Text=	
(
Fix stick to current position:
)
Gui, Main: add, Text,Hidden vtext191419274 X185 Y145,%Text%
Text=	
(
Fix stick to current radius:
)
Gui, Main: add, Text,Hidden vtext19141927 X355 Y145,%Text%
Text= 
Text=	
(
There is no input verification.
Follow instructions and don't try to break it.
)
Gui, Main: add, Text,Hidden vtext1220495721 X170 Y25,%Text%
Text= 
Gui, Main: add, GroupBox,Hidden vtext388795812 X170 Y25 W510 H128,Keyboard Movement
Gui, Main: add, GroupBox,Hidden vtext483483623 X170 Y170 W510 H103,Extra Keyboard Keys
Iniread,master_var,settings.ini,KeyboardMovement>Keys,upKey									
hotkey1964265821_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden Limit190 vhotkey1964265821 X290 Y40 W75,% RegExReplace(master_var,"#")
Iniread,master_var,settings.ini,KeyboardMovement>Keys,downKey									
hotkey599253628_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden Limit190 vhotkey599253628 X290 Y65 W75,% RegExReplace(master_var,"#")
Iniread,master_var,settings.ini,KeyboardMovement>Keys,leftKey									
hotkey1278963789_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden Limit190 vhotkey1278963789 X290 Y115 W75,% RegExReplace(master_var,"#")
Iniread,master_var,settings.ini,KeyboardMovement>Keys,rightKey									
hotkey2130103637_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden Limit190 vhotkey2130103637 X290 Y90 W75,% RegExReplace(master_var,"#")
Iniread,master_var,settings.ini,KeyboardMovement>Keys,walkToggleKey									
hotkey225514912_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden Limit190 vhotkey225514912 X290 Y190 W75,% RegExReplace(master_var,"#")
Iniread,master_var,settings.ini,KeyboardMovement>Keys,lockZLToggleKey									
hotkey83004604_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden Limit190 vhotkey83004604 X290 Y215 W75,% RegExReplace(master_var,"#")
Iniread,master_var,settings.ini,KeyboardMovement>Keys,gyroToggleKey									
hotkey83004605_oldkey:=master_var															
Gui, Main: add, Hotkey, Hidden Limit190 vhotkey83004605 X290 Y240 W75,% RegExReplace(master_var,"#")
Text=	
(
Up
)
Gui, Main: add, Text,Hidden vtext587730748 X185 Y45,%Text%
Text= 
Text=	
(
Down
)
Gui, Main: add, Text,Hidden vtext530033183 X185 Y70,%Text%
Text= 
Text=	
(
Left
)
Gui, Main: add, Text,Hidden vtext2143338622 X185 Y120,%Text%
Text= 
Text=	
(
Right
)
Gui, Main: add, Text,Hidden vtext172497039 X185 Y95,%Text%
Text= 
Text=	
(
Toggle Walk
)
Gui, Main: add, Text,Hidden vtext996303547 X185 Y195,%Text%
Text= 
Text=	
(
Toggle ZL Lock
)
Gui, Main: add, Text,Hidden vtext863373581 X185 Y220,%Text%
Text= 
Text=	
(
Toggle Gyro
)
Gui, Main: add, Text,Hidden vtext863373582 X185 Y245,%Text%
Text= 
Iniread,master_var,settings.ini,Extra Settings,hideCursor									
boxName=																				
(
Hide when controller is on.
)
checkMe:=(master_var="1" ) ? 1:(master_var="0" ? 0:-1)
Gui, Main: add, Checkbox, Hidden  Checked%checkMe% vcheckbox1135789786 X185 Y215,%boxName%
boxName= 
Gui, Main: add, GroupBox,Hidden vtext1829586573 X170 Y195 W520 H45,Cursor
Gui, Main: add, GroupBox,Hidden vtext833212790 X170 Y25 W520 H45,Enable BotW MouseWheel Weapon Change Feature
Gui, Main: add, GroupBox,Hidden vtext1505650515 X170 Y80 W520 H45,Enable ZL Lock Key Feature
;Gui, Main: add, GroupBox,Hidden vtext1612995781 X170 Y140 W520 H45,Enable nonlinear visual aid
Iniread,master_var,settings.ini,Extra Settings,BotWmouseWheel
checkMe:= (master_var="1") ? 1:0
Gui, Main: Add, Radio, Hidden Section Group Checked%checkMe% vradio2102688731_1 X185 Y45, Yes
checkMe:= (master_var="0") ? 1:0
Gui, Main: Add, Radio, Hidden ys Checked%checkMe% vradio2102688731_2,  No
Iniread,master_var,settings.ini,Extra Settings,lockZL
checkMe:= (master_var="1") ? 1:0
Gui, Main: Add, Radio, Hidden Section Group Checked%checkMe% vradio2030676791_1 X185 Y100, Yes
checkMe:= (master_var="0") ? 1:0
Gui, Main: Add, Radio, Hidden ys Checked%checkMe% vradio2030676791_2, No               Note: key must also be set on KeyboardMovement>Keys

Iniread,master_var,settings.ini,Extra Settings,nnVA
; Button number: 1.
checkMe:= (master_var="1") ? 1:0
Gui, Main: Add, Radio, Hidden Section Group Checked%checkMe% vradio487673732_1 X185 Y160, Yes
; Button number: 2.
checkMe:= (master_var="0") ? 1:0
Gui, Main: Add, Radio, Hidden ys Checked%checkMe% vradio487673732_2,  No

Return 
SubmitAll:
submit_General:
	edit1092695107:=RegExReplace(edit1092695107,"`n","DELIM_|_ITER")				
	IniWrite,%edit1092695107%, settings.ini, General, gameExe
		If (radio1244113855_1=1)
			IniWrite,1, settings.ini, General, mouse2joystick
		If (radio1244113855_2=1)
			IniWrite,0, settings.ini, General, mouse2joystick
		If (radio1371042200_1=1)
			IniWrite,1, settings.ini, General, autoActivateGame
		If (radio1371042200_2=1)
			IniWrite,0, settings.ini, General, autoActivateGame
	IniWrite, %vJoyDropDown%, settings.ini, General, vJoyDevice
If submitOnlyOne
	Return
submit_General>Setup:
	edit968841594:=RegExReplace(edit968841594,"`n","DELIM_|_ITER")				
	IniWrite,%edit968841594%, settings.ini, General>Setup, r
	edit1484171716:=RegExReplace(edit1484171716,"`n","DELIM_|_ITER")				
	IniWrite,%edit1484171716%, settings.ini, General>Setup, k
	edit1441011004:=RegExReplace(edit1441011004,"`n","DELIM_|_ITER")
	IniWrite,%edit1441011004%, settings.ini, General>Setup, freq
	edit1136845697:=RegExReplace(edit1136845697,"`n","DELIM_|_ITER")				
	IniWrite,%edit1136845697%, settings.ini, General>Setup, nnp
If submitOnlyOne
	Return
submit_General>Hotkeys:
	hotkey26759803:=hotkey26759803_addWinkey ? "#" . hotkey26759803:hotkey26759803
	IF (!hotkey26759803)
		hotkey26759803 := "F1"
	IniWrite,%hotkey26759803%, settings.ini, General>Hotkeys, controllerSwitchKey
	hotkey255211840:=hotkey255211840_addWinkey ? "#" . hotkey255211840:hotkey255211840
	IF (!hotkey255211840 or hotkey255211840 = "#")
		hotkey255211840 := "#q"
	IniWrite,%hotkey255211840%, settings.ini, General>Hotkeys, exitKey
If submitOnlyOne
	Return
submit_Mouse2Joystick:
If submitOnlyOne
	Return
submit_Mouse2Joystick>Axes:
	edit446078763:=RegExReplace(edit446078763,"`n","DELIM_|_ITER")				
	IniWrite,%edit446078763%, settings.ini, Mouse2Joystick>Axes, angularDeadZone
		If (radio1025876589_1=1)
			IniWrite,1, settings.ini, Mouse2Joystick>Axes, invertedX
		If (radio1025876589_2=1)
			IniWrite,0, settings.ini, Mouse2Joystick>Axes, invertedX
		If (radio122217493_1=1)
			IniWrite,1, settings.ini, Mouse2Joystick>Axes, invertedY
		If (radio122217493_2=1)
			IniWrite,0, settings.ini, Mouse2Joystick>Axes, invertedY
If submitOnlyOne
	Return
submit_Mouse2Joystick>Keys:
	edit1874406880:=RegExReplace(edit1874406880,"`n","DELIM_|_ITER")				
	IniWrite,%edit1874406880%, settings.ini, Mouse2Joystick>Keys, joystickButtonKeyList
	hotkey932981360:=hotkey932981360_addWinkey ? "#" . hotkey932981360:hotkey932981360
	IniWrite,%hotkey932981360%, settings.ini, Mouse2Joystick>Keys, autoHoldStickKey
	
	hotkey93298136:=hotkey93298136_addWinkey ? "#" . hotkey93298136:hotkey93298136
	IniWrite,%hotkey93298136%, settings.ini, Mouse2Joystick>Keys,fixRadiusKey
	
If submitOnlyOne
	Return
submit_KeyboardMovement:
If submitOnlyOne
	Return
submit_KeyboardMovement>Keys:
	hotkey1964265821:=RegExReplace(hotkey1964265821,"[!^+]+")
	hotkey1964265821:=hotkey1964265821_addWinkey ? "#" . hotkey1964265821:hotkey1964265821
	IF (!hotkey1964265821)
		hotkey1964265821 := "w"
	IniWrite,%hotkey1964265821%, settings.ini, KeyboardMovement>Keys, upKey
	hotkey599253628:=RegExReplace(hotkey599253628,"[!^+]+")
	hotkey599253628:=hotkey599253628_addWinkey ? "#" . hotkey599253628:hotkey599253628
	IF (!hotkey599253628)
		hotkey599253628 := "s"
	IniWrite,%hotkey599253628%, settings.ini, KeyboardMovement>Keys, downKey
	hotkey1278963789:=RegExReplace(hotkey1278963789,"[!^+]+")
	hotkey1278963789:=hotkey1278963789_addWinkey ? "#" . hotkey1278963789:hotkey1278963789
	IF (!hotkey1278963789)
		hotkey1278963789 := "a"
	IniWrite,%hotkey1278963789%, settings.ini, KeyboardMovement>Keys, leftKey
	hotkey2130103637:=RegExReplace(hotkey2130103637,"[!^+]+")
	hotkey2130103637:=hotkey2130103637_addWinkey ? "#" . hotkey2130103637:hotkey2130103637
	IF (!hotkey2130103637)
		hotkey2130103637 := "d"
	IniWrite,%hotkey2130103637%, settings.ini, KeyboardMovement>Keys, rightKey
	hotkey225514912:=RegExReplace(hotkey225514912,"[!^+]+")
	hotkey225514912:=hotkey225514912_addWinkey ? "#" . hotkey225514912:hotkey225514912
	IniWrite,%hotkey225514912%, settings.ini, KeyboardMovement>Keys, walkToggleKey
	hotkey83004604:=RegExReplace(hotkey83004604,"[!^+]+")
	;hotkey83004604:=hotkey83004604_addWinkey ? "#" . hotkey83004604:hotkey83004604
	IniWrite,%hotkey83004604%, settings.ini, KeyboardMovement>Keys, lockZLToggleKey
	hotkey83004605:=RegExReplace(hotkey83004605,"[!^+]+")
	hotkey83004605:=hotkey83004605_addWinkey ? "#" . hotkey83004605:hotkey83004605
	IniWrite,%hotkey83004605%, settings.ini, KeyboardMovement>Keys, gyroToggleKey
If submitOnlyOne
	Return
submit_Visual_aid:
			writeVal:=(checkbox1135789786=1) ? "1" : "0"
			IniWrite,%writeVal%, settings.ini, Extra Settings, hideCursor
		If (radio2102688731_1=1)
			IniWrite,1, settings.ini, Extra Settings, BotWmouseWheel
		If (radio2102688731_2=1)
			IniWrite,0, settings.ini, Extra Settings, BotWmouseWheel
		If (radio2030676791_1=1)
			IniWrite,1, settings.ini, Extra Settings, lockZL
		If (radio2030676791_2=1)
			IniWrite,0, settings.ini, Extra Settings, lockZL
		
		If (radio487673732_1=1)
			IniWrite,1, settings.ini, Extra Settings, nnVA
		If (radio487673732_2=1)
			IniWrite,0, settings.ini, Extra Settings, nnVA
If submitOnlyOne
	Return
Return
General:
GuiControl, Main: Show%hideShow%, edit1092695107
GuiControl, Main: Enable%hideShow%, edit1092695107
GuiControl, Main: Show%hideShow%, text23478877
GuiControl, Main: Show%hideShow%, text1153671792
GuiControl, Main: Show%hideShow%, text1396826083
GuiControl, Main: Show%hideShow%, vJoyGroupBox
GuiControl, Main: Show%hideShow%, radio1244113855_1
GuiControl, Main: Enable%hideShow%, radio1244113855_1
GuiControl, Main: Show%hideShow%, radio1244113855_2
GuiControl, Main: Enable%hideShow%, radio1244113855_2
GuiControl, Main: Show%hideShow%, radio1371042200_1
GuiControl, Main: Enable%hideShow%, radio1371042200_1
GuiControl, Main: Show%hideShow%, radio1371042200_2
GuiControl, Main: Enable%hideShow%, radio1371042200_2
/*
The name of the executable that will recieve the output.
*/
GuiControl, Main: Show%hideShow%, text1439415306
/*
Automatically activate executable  (If it is running)  when controller is switched on.
*/
GuiControl, Main: Show%hideShow%, text1649409801
GuiControl, Main: Show%hideShow%, vJoyDropDown
Return
General>Setup:
GuiControl, Main: Show%hideShow%, edit968841594
GuiControl, Main: Enable%hideShow%, edit968841594
GuiControl, Main: Show%hideShow%, edit1484171716
GuiControl, Main: Enable%hideShow%, edit1484171716
GuiControl, Main: Show%hideShow%, edit1441011004
GuiControl, Main: Enable%hideShow%, edit1441011004
GuiControl, Main: Show%hideShow%, edit1136845697
GuiControl, Main: Enable%hideShow%, edit1136845697
GuiControl, Main: Show%hideShow%, text1820027441
GuiControl, Main: Show%hideShow%, text1761503059
GuiControl, Main: Show%hideShow%, text868645638
GuiControl, Main: Show%hideShow%, text303295627
/*
1 is linear, <1 lowers sensitivity away from center, >1 hightens sensitivity away center.
*/
GuiControl, Main: Show%hideShow%, text1950133817
/*
Range, (0,1). The center area where no output is sent.
*/
GuiControl, Main: Show%hideShow%, text1365655690
/*
ms. Snaps back to center when entering inner ring, and pauses. Set to -1 to disable.
*/
GuiControl, Main: Show%hideShow%, text1314749378
/*
Range, (0,Screen Height/2). Lower values corresponds to higher sensitivity.
*/
GuiControl, Main: Show%hideShow%, text68851252
Return
General>Hotkeys:
GuiControl, Main: Show%hideShow%, text495210823
GuiControl, Main: Show%hideShow%, text199783574
GuiControl, Main: Show%hideShow%, text1265532956
GuiControl, Main: Show%hideShow%, hotkey26759803
GuiControl, Main: Enable%hideShow%, hotkey26759803
GuiControl, Main: Show%hideShow%, hotkey26759803_addWinkey
GuiControl, Main: Enable%hideShow%, hotkey26759803_addWinkey
GuiControl, Main: Show%hideShow%, hotkey255211840
GuiControl, Main: Enable%hideShow%, hotkey255211840
GuiControl, Main: Show%hideShow%, hotkey255211840_addWinkey
GuiControl, Main: Enable%hideShow%, hotkey255211840_addWinkey
GuiControl, Main: Show%hideShow%, hotkey2127896190
GuiControl, Main: Enable%hideShow%, hotkey2127896190
GuiControl, Main: Show%hideShow%, hotkey2127896190_addWinkey
GuiControl, Main: Enable%hideShow%, hotkey2127896190_addWinkey
Return
Mouse2Joystick:
/*
There is no input verification.
Follow instructions and don't try to break it.
*/
GuiControl, Main: Show%hideShow%, text938990667
Return
Mouse2Joystick>Axes:
GuiControl, Main: Show%hideShow%, edit446078763
GuiControl, Main: Enable%hideShow%, edit446078763
GuiControl, Main: Show%hideShow%, text1772933493
GuiControl, Main: Show%hideShow%, text11683084
GuiControl, Main: Show%hideShow%, text1550313039
GuiControl, Main: Show%hideShow%, radio1025876589_1
GuiControl, Main: Enable%hideShow%, radio1025876589_1
GuiControl, Main: Show%hideShow%, radio1025876589_2
GuiControl, Main: Enable%hideShow%, radio1025876589_2
GuiControl, Main: Show%hideShow%, radio122217493_1
GuiControl, Main: Enable%hideShow%, radio122217493_1
GuiControl, Main: Show%hideShow%, radio122217493_2
GuiControl, Main: Enable%hideShow%, radio122217493_2
/*
Range: [0,45]. Defines the area where only one axis is used.
*/
GuiControl, Main: Show%hideShow%, text374447714
Return
Mouse2Joystick>Keys:
GuiControl, Main: Show%hideShow%, edit1874406880
GuiControl, Main: Enable%hideShow%, edit1874406880
GuiControl, Main: Show%hideShow%, KeyListHelperButton
GuiControl, Main: Enable%hideShow%, KeyListHelperButton
GuiControl, Main: Show%hideShow%, text906325482
;KeyList Page
;GuiControl, Main: Show%hideShow%, text1019731688
;GuiControl, Main: Show%hideShow%, hotkey932981360
;GuiControl, Main: Enable%hideShow%, hotkey932981360
;GuiControl, Main: Show%hideShow%, hotkey932981360_addWinkey
;GuiControl, Main: Enable%hideShow%, hotkey932981360_addWinkey

;GuiControl, Main: Show%hideShow%, hotkey93298136
;GuiControl, Main: Enable%hideShow%, hotkey93298136
;GuiControl, Main: Show%hideShow%, hotkey93298136_addWinkey
;GuiControl, Main: Enable%hideShow%, hotkey93298136_addWinkey

/*
The key list is a comma delimited list of (ahk valid) keys, where each entry binds to a joystick button.
The first entry binds to the first joystick buttons, and so on. Blanks and modifiers are allowed.
*/
GuiControl, Main: Show%hideShow%, text789866609
/*
Fix stick to current position:
*/
;GuiControl, Main: Show%hideShow%, text191419274
;GuiControl, Main: Show%hideShow%, text19141927
Return
KeyboardMovement:
/*
There is no input verification.
Follow instructions and don't try to break it.
*/
GuiControl, Main: Show%hideShow%, text1220495721
Return
KeyboardMovement>Keys:
GuiControl, Main: Show%hideShow%, text388795812
GuiControl, Main: Show%hideShow%, text483483623
GuiControl, Main: Show%hideShow%, hotkey1964265821
GuiControl, Main: Enable%hideShow%, hotkey1964265821
GuiControl, Main: Show%hideShow%, hotkey1964265821_addWinkey
GuiControl, Main: Enable%hideShow%, hotkey1964265821_addWinkey
GuiControl, Main: Show%hideShow%, hotkey599253628
GuiControl, Main: Enable%hideShow%, hotkey599253628
GuiControl, Main: Show%hideShow%, hotkey599253628_addWinkey
GuiControl, Main: Enable%hideShow%, hotkey599253628_addWinkey
GuiControl, Main: Show%hideShow%, hotkey1278963789
GuiControl, Main: Enable%hideShow%, hotkey1278963789
GuiControl, Main: Show%hideShow%, hotkey1278963789_addWinkey
GuiControl, Main: Enable%hideShow%, hotkey1278963789_addWinkey
GuiControl, Main: Show%hideShow%, hotkey2130103637
GuiControl, Main: Enable%hideShow%, hotkey2130103637
GuiControl, Main: Show%hideShow%, hotkey2130103637_addWinkey
GuiControl, Main: Enable%hideShow%, hotkey2130103637_addWinkey
GuiControl, Main: Show%hideShow%, hotkey225514912
GuiControl, Main: Enable%hideShow%, hotkey225514912
GuiControl, Main: Show%hideShow%, hotkey225514912_addWinkey
GuiControl, Main: Enable%hideShow%, hotkey225514912_addWinkey
GuiControl, Main: Show%hideShow%, hotkey83004604
GuiControl, Main: Enable%hideShow%, hotkey83004604
;GuiControl, Main: Show%hideShow%, hotkey83004604_addWinkey
;GuiControl, Main: Enable%hideShow%, hotkey83004604_addWinkey
GuiControl, Main: Show%hideShow%, hotkey83004605
GuiControl, Main: Enable%hideShow%, hotkey83004605
/*
Up
*/
GuiControl, Main: Show%hideShow%, text587730748
/*
Down
*/
GuiControl, Main: Show%hideShow%, text530033183
/*
Left
*/
GuiControl, Main: Show%hideShow%, text2143338622
/*
Right
*/
GuiControl, Main: Show%hideShow%, text172497039
/*
Toggle Walk Text
*/
GuiControl, Main: Show%hideShow%, text996303547
/*
ZL Toggle Text
*/
GuiControl, Main: Show%hideShow%, text863373581
/*
Gyro Toggle Text
*/
GuiControl, Main: Show%hideShow%, text863373582
Return
Extra_Settings:
GuiControl, Main: Show%hideShow%, checkbox1135789786
GuiControl, Main: Enable%hideShow%, checkbox1135789786
GuiControl, Main: Show%hideShow%, text1829586573
GuiControl, Main: Show%hideShow%, text833212790
GuiControl, Main: Show%hideShow%, text1505650515
GuiControl, Main: Show%hideShow%, radio2102688731_1
GuiControl, Main: Enable%hideShow%, radio2102688731_1
GuiControl, Main: Show%hideShow%, radio2102688731_2
GuiControl, Main: Enable%hideShow%, radio2102688731_2
GuiControl, Main: Show%hideShow%, radio2030676791_1
GuiControl, Main: Enable%hideShow%, radio2030676791_1
GuiControl, Main: Show%hideShow%, radio2030676791_2
GuiControl, Main: Enable%hideShow%, radio2030676791_2

; NNVA
;GuiControl, Main: Show%hideShow%, text1612995781
;GuiControl, Main: Show%hideShow%, radio487673732_1
;GuiControl, Main: Enable%hideShow%, radio487673732_1
;GuiControl, Main: Show%hideShow%, radio487673732_2
;GuiControl, Main: Enable%hideShow%, radio487673732_2

Return
TV_LoadTree(tree)
{
	Loop, Parse, tree,`n,`r
	{
		node=%A_LoopField%
		Loop, Parse, node,;
			head%A_Index%:=A_LoopField
		break
	}
	If !head2
		Return
	parentID:=TV_Add(head2,,"+expand")
	load(head4,parentID)
	parentID:=TV_GetParent(parentID)
	load(head3,parentID)
Return
}
load(relativeID,parentID)
{
	nextSibling=
	nextChild=
	nodeName=
	getNode(nextSibling,nextChild,nodeName,relativeID)
	If nodeName
		parentID:=TV_Add(nodeName,parentID,"+expand")
	If nextChild
	{
		load(nextChild,parentID)
	}
	If nextSibling
	{
		parentID:=TV_GetParent(parentID)
		load(nextSibling,parentID)
	}
	Return
}
getNode(ByRef sibling, ByRef child, ByRef nodeName, nodeID)
{
	Global tree
	firstLoop:=1
	Loop, Parse, tree,`n,`r
	{
		If firstLoop
		{
			firstLoop:=0
			continue
		}
		node:=A_LoopField
		Loop, Parse, node,;
		{
			id:=A_LoopField
			break
		}
		If (id=nodeID)
		{
			Loop, Parse, node,;
				node%A_Index%:=A_LoopField
			break
		}
	}
	nodeName:=node2
	sibling:=node3
	child:=node4
	Return
}
selectionPath(id)
{
	TV_GetText(name,id)
	If !name
		Return 0
	parentID := id
	Loop
	{
		parentID := TV_GetParent(parentID)
		If !parentID
			break
		parentName=
		TV_GetText(parentName, parentID)
		If parentName
			name = %parentName%>%name%
	}
	Return name
}
readTreeString:
tree=
(
39872096;General;39872384;39872192
39872192;Setup;39872288;0
39872288;Hotkeys;0;0
39872384;Mouse2Joystick;39872960;39872480
39872480;Axes;39872576;0
39872576;Keys;0;0
39872960;KeyboardMovement;39873152;39873056
39873056;Keys;0;0
39873152;Extra Settings;0;0
)
Return

; Default settings in case problem reading/writing to file.
setSettingsToDefault:
	pairsDefault=
(
gameExe=Cemu.exe
mouse2joystick=1
autoActivateGame=1
firstRun=0
vJoyDevice=1
r=40
k=0.02
freq=25
nnp=.55
controllerSwitchKey=F1
exitKey=#q
angularDeadZone=0
invertedX=0
invertedY=1
joystickButtonKeyList=e,LShift,Space,LButton,1,3,LCtrl,RButton,Enter,m,q,c,i,k,j,l,b
autoHoldStickKey=
fixRadiusKey=
upKey=w
downKey=s
leftKey=a
rightKey=d
walkToggleKey=Numpad0
lockZLToggleKey=Numpad1
gyroToggleKey=v
hideCursor=1
BotWmouseWheel=0
lockZL=0
nnVA=1
)
	Loop,Parse,pairsDefault,`n
	{
		StringSplit,keyValue,A_LoopField,=
		%keyValue1%:=keyValue2
	}
	Goto, readSettingsSkippedDueToError
Return

#IF KeyHelperRunning(setToggle)
#IF
KeyListHelper:
Hotkey, IF, KeyHelperRunning(setToggle)
HotKey,~LButton, getControl, On
Hotkey, IF
GUI, Main:Default
GUIControlGet, getKeyList,, edit1874406880
KeyListByNum := []
Loop, Parse, getKeyList, `,
{
	keyName := A_LoopField
	If !keyName
		continue
	KeyListByNum[A_Index] := keyName
}

setToggle := False
GUI, Main:+Disabled
GUI, KeyHelper:New, +HWNDKeyHelperHWND -MinimizeBox +OwnerMain
GUI, Margin, 10, 7.5
GUI, Add, Text, W0 H0 vLoseFocus, Hidden
GUI, Add, Text, w60 R1 Right Section, A
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[1]
GUI, Add, Text, w60 xs R1 Right, B
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[2]
GUI, Add, Text, w60 xs R1 Right, X
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[3]
GUI, Add, Text, w60 xs R1 Right, Y
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[4]
GUI, Add, Text, w60 xs R1 Right, L
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[5]
GUI, Add, Text, w60 xs R1 Right, R
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[6]
GUI, Add, Text, w60 xs R1 Right, ZL
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[7]
GUI, Add, Text, w60 xs R1 Right, ZR
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[8]
GUI, Add, Text, w60 xs R1 Right, +
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[9]
GUI, Add, Text, w60 xs R1 Right, -
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[10]
GUI, Add, Text, w60 ys R1 Right Section, l-click
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[11]
GUI, Add, Text, w60 ys R1 Right Section, r-click
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[12]
GUI, Add, Text, w60 ys R1 Right Section, d-up
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[13]
GUI, Add, Text, w60 xs R1 Right, d-down
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[14]
GUI, Add, Text, w60 xs R1 Right, d-left
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[15]
GUI, Add, Text, w60 xs R1 Right, d-right
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[16]
GUI, Add, Text, w0 xs R1 Right, Dummy
GUI, Add, Text, w60 xs R1 Right, blow-mic
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[17]
GUI, Add, Text, w60 xs R1 Right, show-screen
GUI, Add, Edit, W80 R1 x+m yp-3 Center ReadOnly -TabStop, % KeyListByNum[18]
GUI, Add, Text, w0 xm+230 R1 Right, Dummy
GUI, Add, Button, xp yp-30 w80 gSaveButton Section, Save
GUI, Add, Button, x+m w80 gCancelButton, Cancel
GUI, Add, Button, xs yp-30 w170 gAutoLoop, Auto Cycle
GUI, Add, Button, xs yp-60 w170 gClearButton, Clear

GUI, Show,, KeyList Helper
GuiControl, Focus, LoseFocus
Return

ClearButton:
	GUI, KeyHelper:Default
	Loop 18
		GUIControl,,Edit%A_Index%,
Return

CancelButton:
KeyHelperGUIClose:
	IF (setToggle)
		Return
	Hotkey, IF, KeyHelperRunning(setToggle)
	HotKey,~LButton, getControl, Off
	Hotkey, IF
	GUI, Main:-Disabled
	GUI, KeyHelper:Destroy
Return

SaveButton:
	tempList := ""
	Loop 18
	{
	GUIControlGet, tempKey,,Edit%A_Index%
		tempList .= tempKey . ","
	}
	tempList := SubStr(tempList,1, StrLen(tempList)-1)
GUI, Main:Default
GUIControl,, edit1874406880, %tempList%
GoSub, KeyHelperGUIClose
Return

getControl:
	GUI, KeyHelper:Default
	KeyWait, LButton

	setToggle := True
	MouseGetPos,,, mouseWin, useControl, 1
	IF (InStr(useControl, "Edit") AND mouseWin = KeyHelperHWND)
		GetKey()
	setToggle := False


	clearFocus:
	GuiControl, Focus, LoseFocus
Return

AutoLoop:
	GUI, KeyHelper:Default
	Loop 4
		GUIControl, +Disabled, Button%A_Index%
	setToggle := True
	Loop 18 {
		useControl := "Edit" . A_Index
		GetKey()
	}
	setToggle := False
	Loop 4
		GUIControl, -Disabled, Button%A_Index%
	GoSub, clearFocus
	MsgBox, Done
Return

KeyHelperRunning(setTog){
	Return (WinActive("KeyList Helper") AND !setTog)
}

GetKey() {
	Global
	GoSub, TurnOn
	MousePressed := False
	GUIControl, -E0x200, %useControl%
	GuiControl,Text, %useControl%, Waiting
	Input, singleKey, L1, {Tab}{Enter}{Space}{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}{AppsKey}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}{Left}{Right}{Up}{Down}{Home}{End}{PgUp}{PgDn}{Del}{Ins}{BS}{Capslock}{Numlock}{PrintScreen}{Pause}{Esc}{NumPad1}{NumPad2}{NumPad3}{NumPad4}{NumPad5}{NumPad6}{NumPad7}{NumPad8}{NumPad9}{NumPad0}{NumPadDiv}{NumPadMult}{NumPadAdd}{NumPadSub}{NumPadEnter}{NumpadDot}
	GoSub, TurnOff
	IF (InStr(ErrorLevel, "EndKey:"))
		singleKey := SubStr(ErrorLevel, 8)
	Else
		singleKey := Format("{:Ls}", singleKey)
	
	IF (MousePressed)
		singleKey := MousePressed
	Else IF (singleKey = "LControl")
		singleKey := "LCtrl"
	Else IF (singleKey = "RControl")
		singleKey := "RCtrl"
		
	GuiControl, Text, %useControl%, %singleKey%
	GUIControl, +E0x200, %useControl%
	Loop 18
	{
		GUIControlGet, tempKey,,Edit%A_Index%
		IF (tempKey = singleKey AND useControl != "Edit" . A_Index)
			GuiControl, Text, Edit%A_Index%,
	}
Return
}

WM_LBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	MousePressed := "LButton"
	GoSub, TurnOff
	Return 0
}

WM_RBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	MousePressed := "RButton"
	GoSub, TurnOff
	Return 0
}

WM_MBUTTONDOWN() {
	Global useControl, MousePressed
	Send, {Esc}
	MousePressed := "MButton"
	GoSub, TurnOff
	Return 0
}

WM_XBUTTONDOWN(w) {
	Global useControl, MousePressed
	Send, {Esc}
	SetFormat, IntegerFast, Hex
	IF ((w & 0xFF) = 0x20)
		MousePressed := "XButton1"
	Else IF((w & 0xFF) = 0x40)
		MousePressed := "XButton2"
	
	GoSub, TurnOff
	Return 0
}

TurnOn:
OnMessage(0x0201, "WM_LBUTTONDOWN")
OnMessage(0x0204, "WM_RBUTTONDOWN")
OnMessage(0x0207, "WM_MBUTTONDOWN")
OnMessage(0x020B, "WM_XBUTTONDOWN")
Return

TurnOff:
OnMessage(0x0201, "")
OnMessage(0x0204, "")
OnMessage(0x0207, "")
OnMessage(0x020B, "")
Return

