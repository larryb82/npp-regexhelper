library nppRegEx;

uses
  Windows,
  Messages,
  nppplugin,
  scisupport,
  RegExPlugin in 'RegExPlugin.pas',
  frmRegExGui in 'frmRegExGui.pas' {RegExGui},
  nppPluginUtils in 'nppPluginUtils.pas';

var
  Functions: Array of TFuncItem;
  LaunchKey: TShortcutKey;
  Handles: TNppData;

procedure setInfo(NppData: TNppData); cdecl; export;
begin
  Handles := NppData;
end;

function getName(): nppPchar; cdecl; export;
begin
  Result := 'RegEx Helper';
end;

function isUnicode : Boolean; cdecl; export;
begin
  Result := true;
end;

procedure beNotified(Msg: PSCNotification); cdecl; export;
var
  MsgFrom: THandle;
  Clear: Boolean;
begin
  MsgFrom := THandle(Msg.nmhdr.hwndFrom);
  Clear := ((MsgFrom = Handles.ScintillaMain) and (Msg.nmhdr.code = SCI_GETCURRENTPOS))
        or ((MsgFrom = Handles.Npp) and (Msg.nmhdr.code = NPPN_BUFFERACTIVATED));

  if Clear then
    NotifyDocChanged
end;

function messageProc(Msg: UINT; wParam: WPARAM; lParam: LPARAM):LRESULT; cdecl; export;
begin
  Result := 0;
end;

procedure CallLaunchRegExHelper; cdecl; export;
begin
  LaunchRegExHelper(Handles);
end;

function getFuncsArray(var ArrayLength: Integer): Pointer; cdecl; export;
begin
  LaunchKey.IsCtrl := True;
  LaunchKey.IsAlt := False;
  LaunchKey.IsShift := False;
  LaunchKey.Key := VK_F12; // use Byte('A') for VK_A-Z


  SetLength(Functions, 1);
  Functions[0].ItemName := 'Launch';
  Functions[0].Func := CallLaunchRegExHelper;
  Functions[0].CmdID := 0;
  Functions[0].Checked := False;
  Functions[0].ShortcutKey := @LaunchKey;

  Result :=  @Functions[0];
  ArrayLength := Length(Functions);
end;

exports isUnicode, beNotified, setInfo, getName, messageProc, getFuncsArray;


procedure DllEntryPoint (AReason: Integer);
begin
  case AReason of
    DLL_PROCESS_DETACH:
      RegExHelperDestroy;
  end;
end;

begin
  DllProc := DllEntryPoint;
  DllProc(DLL_PROCESS_ATTACH);
  ReportMemoryLeaksOnShutdown := DebugHook <> 0;
end.
