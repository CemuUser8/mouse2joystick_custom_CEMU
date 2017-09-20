
Class CvGenInterface {
	DebugMode := 0
	SingleStickMode := 1 	; If set to 1, helper classes will automatically relinquish existing vjoy device on attempting to acquire one not connected.
	ResetOnAcquire := 1 	; Resets Devices to vjoy norms on Acquire via helper classes.
	ResetOnRelinquish := 1 	; Resets Devices to vjoy norms on Relinquish via helper classes.
	LibraryLoaded := 0 		; Did the Library Load OK when the class Instantiated?
	
	LoadLibraryLog := ""	; If Not, holds log of why it failed.
	hModule := 0 			; handle to DLL
	Devices := []			; Array for Helper Classes of Devices
	xDevices := []			; Array for Helper Classes of vXbox Devices

	VJD_MAXDEV := 16		; Max Number of Devices vJoy Supports
	VXB_MAXDEV := 4			; Max Number of Devices vXbox Supports

	; ported from VjdStat in vjoyinterface.h
	VJD_STAT_OWN := 0   ; The  vJoy Device is owned by this application.
	VJD_STAT_FREE := 1  ; The  vJoy Device is NOT owned by any application (including this one).
	VJD_STAT_BUSY := 2  ; The  vJoy Device is owned by another application. It cannot be acquired by this application.
	VJD_STAT_MISS := 3  ; The  vJoy Device is missing. It either does not exist or the driver is down.
	VJD_STAT_UNKN := 4  ; Unknown

	; HID Descriptor definitions(ported from public.h)
	HID_USAGE_X := 0x30
	HID_USAGE_Y := 0x31
	HID_USAGE_Z := 0x32
	HID_USAGE_RX:= 0x33
	HID_USAGE_RY:= 0x34
	HID_USAGE_RZ:= 0x35
	HID_USAGE_SL0:= 0x36
	HID_USAGE_SL1:= 0x37

	; Handy lookups to axis HID_USAGE values
	AxisIndex := [0x30,0x31,0x32,0x33,0x34,0x35,0x36,0x37]	; Index (Axis Number) to HID Descriptor
	AxisAssoc := {x:0x30, y:0x31, z:0x32, rx:0x33, ry:0x34, rz: 0x35, sl1:0x36, sl2:0x37} ; Name (eg "x", "y", "z", "sl1") to HID Descriptor
	AxisNames := ["X","Y","Z","RX","RY","RZ","SL0","SL1"]
	
	static DllName := "vGenInterface"

	; ===== Constructors / Destructors
	__New(){
		; Build Device array
		Loop % this.VJD_MAXDEV {
			this.Devices[A_Index] := new this.CvJoyDevice(A_Index, this)
		}
		
		Loop % this.VXB_MAXDEV {
			this.xDevices[A_Index] := new this.CvXBoxDevice(A_Index, this)
		}

		; Try and Load the DLL
		this.LoadLibrary()
		return this
	}

	__Delete(){
		; Relinquish Devices
		Loop % this.VJD_MAXDEV {
			this.Devices[A_Index].Relinquish()
		}
		
		Loop % this.VXB_MAXDEV {
			this.xDevices[A_Index].Relinquish()
		}

		; Unload DLL
		if (this.hModule){
			DllCall("FreeLibrary", "Ptr", this.hModule)
		}
	}

	; ===== Helper Functions
	; Converts vJoy range (0->32768 to a range like an AHK input 0->100)
	PercentTovJoy(percent){
		return percent * 327.68
	}

	vJoyToPercent(vJoy){
		return vJoy / 327.68
	}

	; ===== DLL loading / vJoy Install detection

	; Load the vJoyInterface DLL.
	LoadLibrary() {
		;Global hModule

		if (this.LibraryLoaded) {
			this.LoadLibraryLog .= "Library already loaded. Aborting...`n"
			return 1
		}

		this.LoadLibraryLog := ""

		; Check if vJoy is installed. Even with the DLL, if vJoy is not installed it will not work...
		; Find vJoy install folder by looking for registry key.
		if (A_Is64bitOS && A_PtrSize != 8){
			SetRegView 64
		}
		RegRead vJoyFolder, HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1, InstallLocation

		if (!vJoyFolder){
			this.LoadLibraryLog .= "ERROR: Could not find the vJoy Registry Key.`n`nvJoy does not appear to be installed.`nPlease ensure you have installed vJoy from`n`nhttp://vjoystick.sourceforge.net."
			return 0
		}
		
		; Try to find location of correct DLL.
		; vJoy versions prior to 2.0.4 241214 lack these registry keys - if key not found, advise update.
		if (A_PtrSize == 8){
			; 64-Bit AHK
			DllKey := "DllX64Location"
			SecondFolder := vJoyFolder . "x64"
		} else {
			; 32-Bit AHK
			DllKey := "DllX86Location"
			SecondFolder := vJoyFolder . "x86"
		}
		RegRead DllFolder, HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\{8E31F76F-74C3-47F1-9550-E041EEDC5FBB}_is1, % DllKey

		if (!DllFolder){
			; Could not find registry entry. Advise vJoy update.
			this.LoadLibraryLog .= "A vJoy install was found in " vJoyFolder ", but it appears to be an old version.`nPlease update vJoy to the latest version from `n`nhttp://vjoystick.sourceforge.net."
			DllFolder := SecondFolder
		}

		DllFolder .= "\"

		; All good so far, try and load the DLL
		DllFile := "vGenInterface.dll"
		this.LoadLibraryLog := "vJoy Install Detected. Trying to load " DllFile "...`n"
		CheckLocations := [DllFolder DllFile]

		hModule := 0
		Loop % CheckLocations.Maxindex() {
			this.LoadLibraryLog .= "Checking " CheckLocations[A_Index] "... "
			if (FileExist(CheckLocations[A_Index])){
				this.LoadLibraryLog .= "FOUND.`nTrying to load.. "
				hModule := DLLCall("LoadLibrary", "Str", CheckLocations[A_Index])
				if (hModule){
					this.hModule := hModule
					this.LoadLibraryLog .= "OK.`n"
					this.LoadLibraryLog .= "Checking driver enabled... "
					en := DllCall(DllFile "\vJoyEnabled", "Cdecl")
					if (en){
						this.LibraryLoaded := 1
						this.LoadLibraryLog .= "OK.`n"
						ver := DllCall(DllFile "\GetvJoyVersion", "Cdecl")
						this.LoadLibraryLog .= "Loaded vJoy DLL version " ver "`n"
						vb := this.IsVBusExist()
						if (vb){
							this.LoadLibraryLog .= "SCPVBus is installed`n"
						} else {
							this.LoadLibraryLog .= "SCPVBus is not installed (Non fatal)`n"
						}
						this.SetScpVBusState(vb)
						this._SetInitState(hModule)
						return 1
					} else {
						this.LoadLibraryLog .= "FAILED.`n"
					}
				} else {
					this.LoadLibraryLog .= "FAILED.`n"
				}
			} else {
				this.LoadLibraryLog .= "NOT FOUND.`n"
			}
		}
		this.LoadLibraryLog .= "`nFailed to load valid  " DllFile "`n"
		this.LibraryLoaded := 0
		return 0
	}

	; ===== vJoy Interface DLL call wrappers
	; In the order detailed in the vJoy SDK's Interface Function Reference
	; http://sourceforge.net/projects/vjoystick/files/

	; === General driver data
	
	IsVBusExist(){
		ret := DllCall(this.DllName "\isVBusExist", "Cdecl")
		return (ret == 0)
	}
	
	vJoyEnabled(){
		return DllCall(this.DllName "\vJoyEnabled")
	}

	GetvJoyVersion(){
		return DllCall(this.DllName "\GetvJoyVersion")
	}

	GetvJoyProductString(){
		return DllCall(this.DllName "\GetvJoyProductString")
	}

	GetvJoyManufacturerString(){
		return DllCall(this.DllName "\GetvJoyManufacturerString")
	}

	GetvJoySerialNumberString(){
		return DllCall(this.DllName "\GetvJoySerialNumberString")
	}

	; === Write access to vJoy Device
	GetVJDStatus(rID){
		return DllCall(this.DllName "\GetVJDStatus", "UInt", rID)
	}

	; Handle setting IsOwned property outside helper class, to allow mixing
	AcquireVJD(rID){
		this.Devices[rID].IsOwned := DllCall(this.DllName "\AcquireVJD", "UInt", rID)
		return this.Devices[rID].IsOwned
	}
	
	; Handle setting IsOwned property outside helper class, to allow mixing
	AcquireDev(rID){
		;VarSetCapacity(dev, A_PtrSize)
		useType := 1
		this.xDevices[rID].IsOwned := !DllCall(this.DllName "\AcquireDev", "UInt", rID, "UInt", useType, "Ptr*", dev, "Cdecl")
		this.xDevices[rID].xID := dev
		return this.Devices[rID].IsOwned
	}

	RelinquishVJD(rID){
		DllCall(this.DllName "\RelinquishVJD", "UInt", rID)
		this.Devices[rID].IsOwned := 0
		return this.Devices[rID].IsOwned
	}
	
	RelinquishDev(rID){
		DllCall(this.DllName "\RelinquishDev", "Ptr", this.xDevices[rID].xID)
		this.xDevices[rID].IsOwned := 0
		return this.xDevices[rID].IsOwned
	}

	; Not sure if this one is good. What is a "PVOID"?
	UpdateVJD(rID, pData){
		return DllCall(this.DllName "\UpdateVJD", "UInt", rID, "PVOID", pData)
	}

	; === vJoy Device properties

	GetVJDButtonNumber(rID){
		return DllCall(this.DllName "\GetVJDButtonNumber", "UInt", rID)
	}

	GetVJDDiscPovNumber(rID){
		return DllCall(this.DllName "\GetVJDDiscPovNumber", "UInt", rID)
	}

	GetVJDContPovNumber(rID){
		return DllCall(this.DllName "\GetVJDContPovNumber", "UInt", rID)
	}

	GetVJDAxisExist(rID, Axis){
		return DllCall(this.DllName "\GetVJDAxisExist", "UInt", rID, "Uint", Axis)
	}

	ResetVJD(rID){
		return DllCall(this.DllName "\ResetVJD", "UInt", rID)
	}
	
	ResetController(rID){
		return DllCall(this.DllName "\ResetController", "UInt", rID)
	}

	ResetAll(){
		return DllCall(this.DllName "\ResetAll")
	}

	ResetButtons(rID){
		return DllCall(this.DllName "\ResetButtons", "UInt", rID)
	}

	ResetPovs(rID){
		return DllCall(this.DllName "\ResetPovs", "UInt", rID)
	}

	SetAxis(Value, rID, Axis){
		return DllCall(this.DllName "\SetAxis", "Int", Value, "UInt", rID, "UInt", Axis)
	}
	
	SetDevAxis(Value, rID, Axis){
		return DllCall(this.DllName "\SetDevAxis", "Ptr", this.xDevices[rID].xID, "UInt", Axis, "Float", Value, "Cdecl")
	}

	SetBtn(Value, rID, nBtn){
		return DllCall(this.DllName "\SetBtn", "Int", Value, "UInt", rID, "UInt", nBtn)
	}
	
	SetDevPov(Value, rID, nPov){
		return DllCall(this.DllName "\SetDevPov", "Ptr", this.xDevices[rID].xID,  "UInt", nPov, "Float", Value, "Cdecl")
	}
	
	SetDevBtn(Value, rID, nBtn){
		return DllCall(this.DllName "\SetDevButton", "Ptr", this.xDevices[rID].xID,  "UInt", nBtn, "Uint", Value, "Cdecl")
	}
	
	GetDevHandle(rID){
		DllCall(this.DllName "\GetDevHandle", "Uint", rID,  "UInt", 1, "Ptr*", dev, "Cdecl")
		return dev
	}

	SetDiscPov(Value, rID, nPov){
		return DllCall(this.DllName "\SetDiscPov", "Int", Value, "UInt", rID, "UChar", nPov)
	}

	SetContPov(Value, rID, nPOV){
		return DllCall(this.DllName "\SetContPov", "Int", Value, "UInt", rID, "UChar", nPov)
	}
	
	PlugIn(rID) {
		return DllCall(this.DllName "\PlugIn", "UInt", rID)
	}

	PlugInNext() {
		DllCall(this.DllName "\PlugInNext", "Ptr*", slot)
		return slot
	}
	
	UnPlug(rID) {
		return DllCall(this.DllName "\UnPlug", "UInt", rID)
	}
	
	UnPlugAll() {
		ret := ""
		Loop 4 {
			IF this.isControllerPluggedIn(A_Index)
				ret .= "|" . DllCall(this.DllName "\UnPlugForce", "UInt", A_Index)
		}
		Return ret
	}
	
	isControllerPluggedIn(rID) {
		DLLCall(this.DllName "\isControllerPluggedIn", "UInt", rID, "Ptr*", Exist)
		Return Exist
	}
	
	isControllerOwned(rID) {
		DLLCall(this.DllName "\isControllerOwned", "UInt", rID, "Ptr*", Owned)
		Return Owned
	}
	
	GetLedNumber(rID) {
		DLLCall(this.DllName "\GetLedNumber", "UInt", rID, "Ptr*", pLed)
		Return pLed
	}
	
	
	;;;;;;;;;==================
		; ===== Device helper subclass.
	Class CvJoyDevice {
		IsOwned := 0

		GetStatus(){
			return this.Interface.GetVJDStatus(this.DeviceID)
		}

		; Converts Status to human readable form
		GetStatusName(){
			DeviceStatus := this.GetStatus()
			if (DeviceStatus = this.Interface.VJD_STAT_OWN) {
				return "OWN"
			} else if (DeviceStatus = this.Interface.VJD_STAT_FREE) {
				return "FREE"
			} else if (DeviceStatus = this.Interface.VJD_STAT_BUSY) {
				return "BUSY"
			} else if (DeviceStatus = this.Interface.VJD_STAT_MISS) {
				return "MISS"
			} else {
				return "???"
			}
		}

		; Acquire the device
		Acquire(){
			if (this.IsOwned){
				return 1
			}
			if (this.Interface.SingleStickMode){
				Loop % this.Interface.Devices.MaxIndex() {
					if (A_Index == this.DeviceID){
						Continue
					}
					if (this.Interface.Devices[A_Index].IsOwned){
						this.Interface.Devices[A_Index].Relinquish()
						break
					}
				}
			}
			ret := this.Interface.AcquireVJD(this.DeviceID)
			if (ret && this.Interface.ResetOnAcquire){
				; Reset the Device so it centers
				this.Interface.ResetVJD(this.DeviceID)
			} else {
				if (this.Interface.DebugMode) {
					OutputDebug, % "Error in " A_ThisFunc "`nDeviceID = " this.DeviceID ", ErrorLevel: " ErrorLevel ", Device Status: " this.GetStatusName()
				}
			}
			return ret
		}

		; Relinquish the device, resetting it if Owned
		Relinquish(){
			if (this.IsOwned && this.Interface.ResetOnRelinquish){
				this.Interface.ResetVJD(this.DeviceID)
			}
			return this.Interface.RelinquishVJD(this.DeviceID)
		}

		Reset(){
			this.Interface.ResetVJD(this.DeviceID)
		}

		ResetButtons(){
			this.Interface.ResetButtons(this.DeviceID)
		}

		ResetPovs(){
			this.Interface.ResetButtons(this.DeviceID)
		}

		; Does the device exist or not?
		IsEnabled(){
			state := this.GetStatus()
			return state != this.Interface.VJD_STAT_MISS && state != this.Interface.VJD_STAT_UNKN
		}

		; Is it possible to take control of the device?
		IsAvailable(){
			state := this.GetStatus()
			return state == this.Interface.VJD_STAT_FREE || state == this.Interface.VJD_STAT_OWN
		}

		; Set Axis by Index number.
		; eg x = 1, y = 2, z = 3, rx = 4
		SetAxisByIndex(axis_val, index){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetAxis(axis_val, this.DeviceID, this.Interface.AxisIndex[index])
		}

		; Set Axis by Name
		; eg "x", "y", "z", "rx"
		SetAxisByName(axis_val, name){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetAxis(axis_val, this.DeviceID, this.Interface.AxisAssoc[name])
		}

		SetBtn(btn_val, btn){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetBtn(btn_val, this.DeviceID, btn)
		}

		SetDiscPov(pov_val, pov){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetDiscPov(pov_val, this.DeviceID, pov)
		}

		SetContPov(pov_val, pov){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetContPov(pov_val, this.DeviceID, pov)
		}

		; Constructor
		__New(id, parent){
			this.DeviceID := id
			this.Interface := parent
		}

		; Destructor
		__Delete(){
			this.Relinquish()
		}
	}

	
	;;;;;;;;;==================
	Class CvXBoxDevice {
		IsOwned := 0
		xID := ""
		
		GetStatus(){
			return this.Interface.GetVJDStatus(this.DeviceID)
		}

		; Converts Status to human readable form
		GetStatusName(){
			DeviceStatus := this.GetStatus()
			if (DeviceStatus = this.Interface.VJD_STAT_OWN) {
				return "OWN"
			} else if (DeviceStatus = this.Interface.VJD_STAT_FREE) {
				return "FREE"
			} else if (DeviceStatus = this.Interface.VJD_STAT_BUSY) {
				return "BUSY"
			} else if (DeviceStatus = this.Interface.VJD_STAT_MISS) {
				return "MISS"
			} else {
				return "???"
			}
		}
		
		PlugIn() {
			return this.Interface.PlugInNext()
		}
		
		unPlug() {
			this.IsOwned := 0
			return this.Interface.UnPlug(this.DeviceID)
		}
		
		GetLEDNumber() {
			return this.Interface.GetLedNumber(this.DeviceID)
		}
		

		; Acquire the device
		Acquire(){
			if (this.IsOwned){
				return 1
			}
			if (this.Interface.SingleStickMode){
				Loop % this.Interface.xDevices.MaxIndex() {
					if (A_Index == this.DeviceID){
						Continue
					}
					if (this.Interface.xDevices[A_Index].IsOwned){
						this.Interface.xDevices[A_Index].Relinquish()
						break
					}
				}
			}
			ret := this.Interface.AcquireDev(this.DeviceID)
			if (ret && this.Interface.ResetOnAcquire){
				; Reset the Device so it centers
				this.Interface.ResetController(this.DeviceID)
			} else {
				if (this.Interface.DebugMode) {
					OutputDebug, % "Error in " A_ThisFunc "`nDeviceID = " this.DeviceID ", ErrorLevel: " ErrorLevel ", Device Status: " this.GetStatusName()
				}
			}
			return ret
		}

		; Relinquish the device, resetting it if Owned
		Relinquish(){
			if (this.IsOwned && this.Interface.ResetOnRelinquish){
				this.Interface.ResetController(this.DeviceID)
			}
			return this.Interface.RelinquishDev(this.DeviceID)
		}

		Reset(){
			this.Interface.ResetController(this.DeviceID)
		}

		ResetButtons(){
			this.Interface.ResetController(this.DeviceID)
		}

		ResetPovs(){
			this.Interface.ResetController(this.DeviceID)
		}

		; Does the device exist or not?
		IsEnabled(){
			state := this.GetStatus()
			return state != this.Interface.VJD_STAT_MISS && state != this.Interface.VJD_STAT_UNKN
		}

		; Is it possible to take control of the device?
		IsAvailable(){
			state := this.GetStatus()
			return state == this.Interface.VJD_STAT_FREE || state == this.Interface.VJD_STAT_OWN
		}
		
		IsControllerOwned(){
			return this.Interface.isControllerOwned(this.DeviceID)
		}

		; Set Axis by Index number.
		; eg x = 1, y = 2, z = 3, rx = 4
		SetAxisByIndex(axis_val, index){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetDevAxis(axis_val, this.DeviceID, index)
		}
		

		; Set Axis by Name
		; eg "x", "y", "z", "rx"
		SetAxisByName(axis_val, name){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetDevAxis(axis_val, this.DeviceID, this.Interface.AxisAssoc[name])
		}
		
		SetPOV(POV_dir) {
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetDevPov( POV_dir,this.DeviceID, 1) 
		}

		SetBtn(btn_val, btn){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetDevBtn(btn_val, this.DeviceID, btn)
		}

		SetDiscPov(pov_val, pov){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetDiscPov(pov_val, this.DeviceID, pov)
		}

		SetContPov(pov_val, pov){
			if (!this.Acquire()){
				return 0
			}
			return this.Interface.SetContPov(pov_val, this.DeviceID, pov)
		}

		; Constructor
		__New(id, parent){
			this.DeviceID := id
			this.Interface := parent
		}

		; Destructor
		__Delete(){
			this.Relinquish()
		}
	}
	
}
