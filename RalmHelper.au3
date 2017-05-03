#cs ----------------------------------------------------------------------------

 AutoIt Version: 3.3.8.1
 Author:
 Version:		0.3

 Script Function:
	Helper functions for TRO

 Changelog:
	0.1: Initial version
	0.2: Changed to relative coordinates (Opt("MouseCoordMode", 0))
	0.3: Uses screenscanner to cast in combat instead of clicking at a fixed location.
	     Cleaned up unneeded functions and added more comments

 Todo:
	Implement auto-repair
	Make a "Status window"
	Rewrite to ControlClick for background operations
	Rewrite to a more "Object-like" programming
	Implement general navigation

#ce ----------------------------------------------------------------------------

#include <OCR.au3>
#include-once

; EDIT THIS
Const $RealmFolder = "C:\Client - 3.172"
Const $AccountPassword = "ikkeno"

; DO NOT EDIT ANYTHING BELOW THIS LINE
Opt("MouseCoordMode", 0)
Opt("PixelCoordMode", 0)
Const $CharPosArray[4][2] = [[85, 425], [250, 425], [410, 425], [575, 425]]

; Declaring VARS
Local $Round
Local $RealmHandle
Local $RoomHandle
Local $Durability

; Need to be set in char file
Local $RealmToonName
Local $RealmToonPos[2]


Local $RealmSkipLoot = 1
; Needs to be set if SkipLoot is set to 0.
Local $RealmIgnoreList[2]

; Defaults, can be overridden.
Local $RealmDefStartCombat = 0
Local $RealmDefIndex = 0
Local $RealmAutoResurrect = 0 ; DO NOT ENABLE UNLESS YOU KNOW WHAT YOURE DOING
Local $RealmAfterCombatCastMode = 0
Local $RealmAfterCombatInvul = 0
Local $RealmAfterCombatHeal = 0
Local $RealmAfterCombatInvis = 0
Local $RealmCheckDurability = 0
Local $RealmCheckInterval = 1
Local $RealmMinDurability = 10
Local $RealmLootMode = "ignore" ; "ignore" or "exclusive"


;Object SetFunctions
Func RealmSetSkipLoot($mode)
	$RealmSkipLoot = $mode
EndFunc
Func RealmSetLootMode($mode)
	$RealmLootMode = $mode
EndFunc
Func RealmSetToonName($name)
	$RealmToonName = $name
EndFunc
Func RealmSetToonPos($pos)
	$RealmToonPos = $pos
EndFunc
Func RealmSetAutoResurrect($mode)
	$RealmAutoResurrect = $mode
EndFunc
Func RealmSetDefStartCombat($mode)
	$RealmDefStartCombat = $mode
EndFunc
Func RealmSetDefIndex($index)
	$RealmDefIndex = $index
EndFunc
Func RealmSetIgnoreList($list)
	$RealmIgnoreList = StringSplit($list, "|")
EndFunc
Func RealmSetCheckDurability($mode)
	$RealmCheckDurability = $mode
EndFunc
Func RealmSetCheckInterval($interval)
	$RealmCheckInterval = $interval
EndFunc
Func RealmSetMinDurability($durability)
	$RealmMinDurability = $durability
EndFunc


Func RealmGetToonName()
	Return $RealmToonName
EndFunc

; Count the number of combat cycles
Global $cycles = 0
Global $Faeries = 0



; FUNCS

; ==== LOOTING FUNCTIONS ====

; Loot
Func Loot()
	If WinExists("[TITLE:Treasure List]") Then
		$TreasureHandle = WinGetHandle("[TITLE:Treasure List]")
	ElseIf WinExists("[TITLE:Inventory]") Then
		$TreasureHandle = WinGetHandle("[TITLE:Inventory]")
	Else
		Return
	EndIf

	If $RealmSkipLoot = 0 Then
		CheckLoot($TreasureHandle)
	Else
		WinClose($TreasureHandle)
	EndIf
EndFunc


; CheckLoot
; Arguments: Loot window handle
; Returns: Nothing
; Clicks the top item and checks the window name (item name) for items not in the ignore list
; Uses the global variable $IgnoreList
Func CheckLoot($TreasureHandle, $x = 43, $y = 74)
	WinActivate($TreasureHandle)
	MouseClick("left", $x, $y, 1, 0)
	Sleep(100)

	$Item = WinGetTitle("[ACTIVE]")
	If $Item = "The Realm Online" Then
		; Everything has been picked up. Stop.
		Return
	ElseIf $Item = "Treasure List" Or $Item = "Inventory" Then
		; The click didn't create a new window, probably because there are no more items to check.
		; Stop.
		WinClose($TreasureHandle)
		Return
	ElseIf CompareString($Item) = 0 Then
		; Pick up item
		MouseClick("left", 196, 61)
		Sleep(100)
		Do
		Until MouseGetCursor() <> 15
		Sleep(500)

		; Check next item
		CheckLoot($TreasureHandle, $x, $y)
	ElseIf CompareString($Item) = 1 Then
		; Ignore this item, check next item
		WinClose($Item)
		$y += 16
		Sleep(500)
		CheckLoot($TreasureHandle, $x, $y)
	EndIf

EndFunc


; CompareString
; Loops through ignorelist and compares with the item.
Func CompareString($Item)
	For $i = 0 To $RealmIgnoreList[0]
		If StringInStr($item, $RealmIgnoreList[$i]) Then
			; Skip the item, we're not interested.
			If $RealmLootMode = "ignore" Then
				Return 1
			ElseIf $RealmLootMode = "exclusive" Then
				Return 0
			EndIf
		EndIf
	Next
	If $RealmLootMode = "ignore" Then
		Return 0
	ElseIf $RealmLootMode = "exclusive" Then
		Return 1
	EndIf
EndFunc

;==== COMBAT FUNCTIONS =====

; Start Combat
Func FightMonster($Monster, $x, $y)
	If $RealmDefStartCombat = 0 Then
		MouseClick("left", $x, $y, 1, 0)
		WinWaitActive($Monster, "", 3)
		MouseClick("left", 117, 114, 1, 0)
	Else
		CastTargetedSpell($RealmDefIndex, $x, $y)
	EndIf
	$Round = 0
EndFunc

Func Attack($handle, $x, $y)
	WinActivate($handle)
	MouseClick("left", 117, 10, 1, 0)
	Sleep(200)
	WinActivate($RealmHandle)
	MouseClick("left", $x, $y, 1, 0)
	$Round += 1
EndFunc

; Guard
; Arguments: "Choose an action" window handle
; Returns: Nothing
; Combat function. Just click "Guard"
Func Guard($handle)
	WinActivate($handle)
	MouseClick("left", 194, 64, 1, 0)
	$Round += 1
EndFunc

Func Flee($handle)
	WinActivate($handle)
	MouseClick("left", 183, 88, 1, 0)
	$Round += 1
EndFunc

; CastSpell
; Arguments: Spell index (position in the favorites list)
; Returns: Nothing
; Selects the best way to cast a spell. Call this function when you know a spell can be cast.
Func CastSpell($index)
	$ypos = 50 + (16 * $index)
	If WinExists("Choose an action...") Then
		$ActionHandle = WinGetHandle("Choose an action...")
		; Cast spell
		WinActivate($ActionHandle)
		MouseClick("left", 119, 115, 1, 0)
		$Round += 1
	ElseIf WinExists("Spell List") Then

	ElseIf PixelGetColor(560, 377) = 0x0E8E0D Then
		MouseClick("left", 560, 377, 1, 0)
	Else
		$ToonPos = ScreenScanner($RealmToonName)
		MouseClick("left", $ToonPos[0], $ToonPos[1], 1, 0)
		WinActivate($RealmToonName)
		MouseClick("left", 200, 63, 1, 0)
	EndIf
	Sleep(100)
	WinActivate("Spell List")
	MouseClick("right", 100, $ypos, 1, 0)
	Sleep(100)
	WinClose("Spell List")
	WinActivate($RealmHandle)
EndFunc

; CastTargetedSpell
Func CastTargetedSpell($index, $x, $y)
	CastSpell($index)
	Sleep(200)
	MouseClick("left", $x, $y, 1, 0)
	Sleep(200)
EndFunc

; ExitCombat
; Argument: Game Window Handle
; Returns: Nothing
Func ExitCombat()
	If $RealmCheckDurability = 1 Then
		If Mod($cycles, $RealmCheckInterval) = 0 Then
			CheckDurability()
			If $Durability < $RealmMinDurability Then
				Exit()
			EndIf
		EndIf
	EndIf
	MouseClick("left", 580, 90, 1, 0)
	Sleep(100)
	; When we hit exit, change some vars.
	$cycles += 1
	Return
EndFunc

;==== RELOG/HANDLE FUNCTIONS ====

; RelogHelper
; Arguments: None
; Returns: Game Window Handle
; A function to get the window handle. If the game has crashed, restart it and return the handle.
Func RelogHelper()
	; Fatal errors crash the game (including disconnects)
	; Click OK and restart the game.
	If WinExists("[TITLE:Fatal]") Then
		WinActivate("[TITLE:Fatal]")
		ControlClick("[TITLE:Fatal]", "", "[ID:1]")
		$RealmHandle = 0
		Sleep(2000)
		Return
	EndIf

	; Death handling
	If WinExists("[TITLE:Death]") Then
		If $RealmAutoResurrect = 1 Then
			WinActivate("[TITLE:Death]")
			MouseClick("left", 92, 166, 1, 0)
		Else
			MsgBox(0, "Dead", "You died. Stopping.")
			Exit
		EndIf
	EndIf

	;Info windows
	If WinExists("[TITLE:Info]") Then
		WinActivate("[TITLE:Info]")
		MouseClick("left", 433, 10, 1, 0)
		Return
	EndIf

	; Relog logics
	If WinExists("[CLASS:RealmGame3]") Then
		If $RealmHandle = 0 Then
			$RealmHandle = WinGetHandle("[CLASS:RealmGame3]")
		EndIf
		WinActivate($RealmHandle)
		; If the main control (text input field) exists, then we're in the game.
		; We can just stop the function.
		ControlGetHandle($RealmHandle, "", "[ID:665]")
		if @error = 0 Then
			Return
		EndIf

		; Check if select server screen is up
		ControlGetHandle($RealmHandle, "", "[ID:777]")
		if @error = 0 Then
			MouseClick("left", 232, 241, 1, 0)
			Sleep(2000)
		EndIf

		; Check if login screen is up
		ControlGetHandle($RealmHandle, "", "[ID:701]")
		if @error = 0 Then
			ControlSend($RealmHandle, "", "[ID:701]", $AccountPassword)
			Sleep(200)
			ControlSend($RealmHandle, "", "[ID:701]", "{ENTER}")
			Sleep(2000)
		EndIf

		; Check if select character screen is up
		If PixelGetColor(327, 478) = 0xFE0606 Then
			MouseClick("left", $CharPosArray[$RealmToonPos][0], $CharPosArray[$RealmToonPos][1], 1, 0)
			MouseMove(320,50)
			Sleep(2000)
		EndIf
		Return
	Else ; If game window doesn't exist, start it.
		StartRalm()
		Return
	EndIf
EndFunc

; StartRalm
; Arguments: none
; Returns: Game Window Handle
; Can be called at any time to get the window handle.
; Used by RelogHelper

Func StartRalm()
	If WinExists("[CLASS:RealmGame3]") Then
		Return
	Else
		Run($RealmFolder & "\wlaunch.exe", $RealmFolder)
		WinWait("[CLASS:RealmGame3]")
		$RealmHandle = WinGetHandle("[CLASS:RealmGame3]")
		Return
	EndIf
EndFunc

; ==== MOVEMENT FUNCTIONS ====
Func MoveLeft()
	WinActivate($RealmHandle)
	MouseClick("left", 15, 191)
	Sleep(3000)
EndFunc
Func MoveRight()
	WinActivate($RealmHandle)
	MouseClick("left", 634, 191)
	Sleep(3000)
EndFunc
Func MoveUp()
	WinActivate($RealmHandle)
	MouseClick("left", 344, 34)
	Sleep(3000)
EndFunc
Func MoveDown()
	WinActivate($RealmHandle)
	MouseClick("left", 344, 303)
	Sleep(3000)
EndFunc
Func EnterRoom($EntranceName, $x, $y)
	MouseClick("left", $x, $y, 1, 0)
	Sleep(100)
	WinActivate($EntranceName)
	MouseClick("left", 196, 61, 1, 0)
	Sleep(3000)
EndFunc

; ==== OTHER FUNCTIONS ====

; OCRReadArea
; Arguments: x/y coordinates of a square
; Returns: Read text
Func OCRReadArea($x1, $y1, $x2, $y2)
	WinActivate($RealmHandle)

	; Convert relative coordinates to absolute coordinates for OCR-function
	$winpos = WinGetPos($RealmHandle)
	$OCRx1 = $winpos[0] + $x1
	$OCRy1 = $winpos[1] + $y1
	$OCRx2 = $winpos[0] + $x2
	$OCRy2 = $winpos[1] + $y2
	$FontColor = 0x00FF40

	$string = _OCR($OCRx1, $OCRy1, $OCRx2, $OCRy2, $FontColor)
	Return $string
EndFunc

; CheckDurability
; Returns: Durability of weapon
; Checks the durability of weapon through character info window and OCR
; Will bug if there's lag and it's unable to load char info screen in time.
Func CheckDurability()
	WinActivate($RealmHandle)

	$ToonPos = ScreenScanner($RealmToonName)
	MouseClick("left", $ToonPos[0], $ToonPos[1], 1, 0)
	$ToonHandle = WinGetHandle($RealmToonName)

	; Click "Look At" and wait for 5 seconds
	WinActivate($ToonHandle)
	MouseClick("left", 116, 8, 1, 0)
	Sleep(5000)

	; Click "Equipment" on char screen
	MouseClick("left", 510, 90, 1, 0)
	Sleep(100)

	; Get weapon durability by OCR
	$string = OCRReadArea(555, 275, 585, 289)
	MouseClick("left", 622, 48, 1, 0)
	Sleep(100)

	; Set weapon durability
	If NOT $String = "" Then
		$Durability = $String
	EndIf
	Return $String
EndFunc


; ScreenScanner
; Argument: Game Window Handle, Monster name
; Returns: Nothing
; Checks every 20 pixels of game window for a monster by checking if a health bar appears
; in the top right corner of the window, and then reads the monster name by OCR
; Monster name can be a partial name due to StringInStr()
; Returns x, y coord
Func ScreenScanner($MonsterName)
	WinActivate($RealmHandle)

	; Convert relative coordinates to absolute for OCR
	$WinPos = WinGetPos($RealmHandle)
	$OCRx1 = $WinPos[0] + 481
	$OCRy1 = $WinPos[1] + 30
	$OCRx2 = $WinPos[0] + 641
	$OCRy2 = $WinPos[1] + 40
	$FontColor = 0xFFFFFF

	Local $Output[2]

	; X-coordinate 20-620, Y-coordinate 80-280
	For $x = 20 To 640 Step 15
		For $y = 80 To 280 Step 20
		MouseMove($x, $y, 0)
		Sleep(10)
		$color = PixelGetColor(475, 24)

		; 475, 24 turns black if the mouse is over a monster
		If ($color = 0) Then
			$string = _OCR($OCRx1, $OCRy1, $OCRx2, $OCRy2, $FontColor)

			; Check if the monster name is in the string
			If StringInStr($string, $MonsterName) Then
				$Output[0] = $x
				$Output[1] = $y
				Return $Output
			EndIf ; StringInStr
		EndIf ; Color
		Next ; Y
	Next ; X

	Return 0
EndFunc

