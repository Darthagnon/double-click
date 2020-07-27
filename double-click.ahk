#NoEnv                        ; Recommended for performance and compatibility with future AutoHotkey releases.
SendMode Input                ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%   ; Ensures a consistent starting directory.
#SingleInstance force         ; Allow only one copy to run
SetBatchLines, -1
Return

; Double-click Desktop to toggle hide all icons
; Source: https://autohotkey.com/board/topic/46689-my-first-script-for-hidding-desktop-icons/
; Double-click to go up a folder level
; Source: https://www.autohotkey.com/boards/viewtopic.php?t=31517
; Empty Desktop spot
; Source: https://autohotkey.com/board/topic/82196-solved-double-click-on-the-desktop/page-2
; ----------------------------------------------------------------------------------------
; BUG: (potentially) script does not auto-suspend when a fullscreen application is running. That said, it only triggers if the desktop or Windows Explorer is active.
; BUG: This script may conflict with Stardock Fences or WindowFX, which it aims to help replace.

~LButton::
   if ( IsDblClick() && (hWnd := WinActive("ahk_class CabinetWClass")) && IsEmptySpace() ) ; If in Windows Explorer, double-click empty space to go up a folder level
      NavigateToParentDir(hWnd)
   else if ( IsDblClick() && (hWnd := WinActive("ahk_class WorkerW")) && _DesktopBlankSpot() ) ; If on desktop, double-click to toggle hide desktop icons
      HideIcons()
   Return
   
; "Is this a double-click?" logic; prevent triple-clicking
IsDblClick() {
   Return A_PriorHotkey = A_ThisHotkey && A_TimeSincePriorHotkey < DllCall("GetDoubleClickTime")
}

; Hide desktop icons logic   
HideIcons() {
   ControlGet, HWND, Hwnd,, SysListView321, ahk_class Progman
   if HWND = 
   ControlGet, HWND, Hwnd,, SysListView321, ahk_class WorkerW
   if DllCall("IsWindowVisible", UInt, HWND)
   WinHide, ahk_id %HWND%
   else
   WinShow, ahk_id %HWND%	 
}

; "Is empty desktop space?" logic - avoid firing on double-click of desktop icon
_DesktopBlankSpot()
{
  LVM_GETSELECTEDCOUNT := 0x1000 + 50
  WinGetClass, Class, A
  if (Class != "WorkerW") and (Class != "Progman")
    return false
  handle := WinExist("A")
  handle := DllCall("GetWindow","Ptr",handle,"Uint",5,"Ptr")
  if (! handle)
    return false
  handle := DllCall("GetWindow","Ptr",handle,"Uint",5,"Ptr")
  if (! handle)
    return false
  SendMessage,%LVM_GETSELECTEDCOUNT%,0,0,,ahk_id %handle%
  return (! ErrorLevel) ; nothing selected = clicked on blank spot
}

; "Is empty space [Windows Explorer]?" logic
IsEmptySpace() {
   static ROLE_SYSTEM_LIST := 0x21
   CoordMode, Mouse
   MouseGetPos, X, Y
   AccObj := AccObjectFromPoint(idChild, X, Y)
   Return AccObj.accRole(0) = ROLE_SYSTEM_LIST
}

; "Object distance" logic (to figure out if empty space)
AccObjectFromPoint(ByRef _idChild_ = "", x = "", y = "") {
   static VT_DISPATCH := 9, F_OWNVALUE := 1, h := DllCall("LoadLibrary", "Str", "oleacc", "Ptr")
   
   (x = "" || y = "") ? DllCall("GetCursorPos", "Int64P", pt) : pt := x & 0xFFFFFFFF | y << 32
   VarSetCapacity(varChild, 8 + 2*A_PtrSize, 0)
   if DllCall("oleacc\AccessibleObjectFromPoint", "Int64", pt, "PtrP", pAcc, "Ptr", &varChild) = 0
      Return ComObject(VT_DISPATCH, pAcc, F_OWNVALUE), _idChild_ := NumGet(varChild, 8, "UInt")
}

; "Go up a folder level" logic
NavigateToParentDir(hWnd) {
   static comType := (VT_ARRAY := 0x2000) | (VT_UI1 := 0x11)
   Shell := ComObjCreate("Shell.Application")
   for Window in Shell.Windows  {
      if (hWnd = Window.hwnd)  {
         Folder := Window.Document.Folder
         parentDirPath := Folder.ParentFolder.Self.Path
         break
      }
   }
   if parentDirPath {
      DllCall("shell32\SHParseDisplayName", "WStr", parentDirPath, "Ptr", 0, "PtrP", PIDL, "UInt", 0, "Ptr", 0)
      ilSize := DllCall("shell32\ILGetSize", "Ptr", PIDL, "UInt")
      VarSetCapacity(SAFEARRAY, 16 + A_PtrSize*2, 0)
      NumPut(1     , SAFEARRAY)
      NumPut(1     , SAFEARRAY, 4)
      NumPut(PIDL  , SAFEARRAY, 8 + A_PtrSize)
      NumPut(ilSize, SAFEARRAY, 8 + A_PtrSize*2)
      try Window.Navigate2( ComObject(comType, &SAFEARRAY), 0 )
      DllCall("shell32\ILFree", "Ptr", PIDL)
   }
}