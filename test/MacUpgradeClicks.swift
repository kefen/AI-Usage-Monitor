import AppKit
import ApplicationServices
let appPath = CommandLine.arguments[1]
func fail(_ msg:String) -> Never { fputs(msg+"\n",stderr); exit(1) }
func get(_ e:AXUIElement,_ k:String)->CFTypeRef? {
    var v:CFTypeRef?; return AXUIElementCopyAttributeValue(e,k as CFString,&v) == .success ? v:nil
}
func match(_ e:AXUIElement,_ value:String,_ depth:Int=0)->AXUIElement? {
    if ["AXIdentifier","AXTitle","AXValue","AXDescription"].contains(where:{(get(e,$0) as? String) == value}) {return e}
    if depth<18 {for c in get(e,"AXChildren") as? [AXUIElement] ?? [] {if let found=match(c,value,depth+1){return found}}}
    return nil
}
func wait(_ value:String, excluding:pid_t=0)->(AXUIElement,pid_t) {
    for _ in 0..<180 {
        if let app=NSWorkspace.shared.runningApplications.first(where:{$0.bundleURL?.path==appPath && $0.processIdentifier != excluding}),
           let found=match(AXUIElementCreateApplication(app.processIdentifier),value){return (found,app.processIdentifier)}
        RunLoop.current.run(until: Date().addingTimeInterval(0.5))
    }
    fail("Visible control not found: "+value)
}
func capture(_ name:String){
    let p=Process();p.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture");p.arguments=["-x","evidence/"+name+".png"]
    do{try p.run();p.waitUntilExit()}catch{fail("Screenshot unavailable")}
    if p.terminationStatus != 0 {fail("Screen capture not authorized")}
}
func press(_ e:AXUIElement){if AXUIElementPerformAction(e,kAXPressAction as CFString) != .success{fail("Native button did not accept press")}}
guard AXIsProcessTrusted() else {fail("Runner lacks Accessibility permission for native GUI control")}
let (_,old)=wait("macOS 0.5.4-alpha.5")
let (badge,_)=wait("update-notice");capture("01-automatic-badge");press(badge)
let (next,_)=wait("Continue");capture("02-confirm");press(next)
Thread.sleep(forTimeInterval:0.3);capture("03-download")
_=wait("Restart the companion to install the verified update? Codex stays open.")
let (install,_)=wait("Continue");capture("04-install");press(install)
_=wait("macOS 0.6.0-alpha.1",excluding:old);capture("05-new-process-version")
