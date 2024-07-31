#Requires AutoHotkey v2.0
#SingleInstance Force

#Include <Neutron>
#Include <JSON>
#Include <LCU>
#Include <API>
#Include <dbg>
#Include <plugins>

neutron := NeutronWindow()
	.OnEvent("close", (neutron) => ExitApp())
	.Load("Bootstrap/bootstrap.html")
	.Show("x0 y0 w600 h300", "LoL")
	
if False {
	FileInstall "Bootstrap/bootstrap.html", "*"
	FileInstall "Bootstrap/bootstrap.min.css", "*"
	FileInstall "Bootstrap/bootstrap.min.js", "*"
	FileInstall "Bootstrap/jquery.min.js", "*"
}

for k, v in plugins
	button := neutron.doc.createElement("button")
; Ex4_Table2 := [["Apple", 1], ["Orange", 2]]
; for row, data in Ex4_Table2 {
; 	tr := neutron.doc.createElement("tr")
; 	for col, cell in data {
; 		td := neutron.doc.createElement("td")
; 		td.innerText := cell
; 		tr.appendChild(td)
; 	}
; 	neutron.qs("#ex4_table2>tbody").appendChild(tr)
; }
SetTimer(autoTFT, 1000)
return
; MsgBox(APICall("GET", "/lol-gameflow/v1/gameflow-phase"))
; msgbox(LCU.Host "/liveclientdata/gamestats")

$^x::ExitApp
$^r::Reload