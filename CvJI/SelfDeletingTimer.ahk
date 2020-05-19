;https://autohotkey.com/boards/viewtopic.php?t=13010

class SelfDeletingTimer {
    __New(period, fn, prms*) {
        this.fn := IsObject(fn) ? fn : Func(fn)
        this.prms := prms
        SetTimer % this, % period
    }
    Call() {
        this.fn.Call(this.prms*)
        SetTimer % this, Delete
    }
}
