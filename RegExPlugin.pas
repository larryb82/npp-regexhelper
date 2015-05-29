unit RegExPlugin;

interface
uses Windows, nppplugin, scisupport;

procedure NotifyDocChanged;
procedure LaunchRegexHelper(const Handles: TNppData);
procedure RegExHelperDestroy;

implementation
uses Forms, frmRegExGui;

var
  RegExHelper: TRegExGui = nil;

procedure LaunchRegexHelper(const Handles: TNppData);
begin
  if not Assigned(RegExHelper) then
    RegExHelper := TRegExGui.CreateParented(Handles.Npp);
  RegExHelper.NppHandles := Handles;

  SendMessage(RegExHelper.NppHandles.Npp, NPPM_MODELESSDIALOG, RegExHelper.Handle, MODELESSDIALOGADD);
  SendMessage(RegExHelper.NppHandles.ScintillaMain, SCI_SETMODEVENTMASK, SC_MOD_INSERTTEXT or SC_MOD_DELETETEXT, 0);
  RegExHelper.Show;
  SendMessage(RegExHelper.NppHandles.Npp, NPPM_MODELESSDIALOG, RegExHelper.Handle, MODELESSDIALOGREMOVE);
end;

procedure RegExHelperDestroy;
begin
  if Assigned(RegExHelper) then
  begin
    RegExHelper.ParentWindow := 0;
    RegExHelper.Free;
    RegExHelper := nil;
  end;
end;

procedure NotifyDocChanged;
begin
  if Assigned(RegExHelper) then RegExHelper.ClearMatches;
end;

end.
