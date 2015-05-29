unit frmRegExGui;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls, StdCtrls, SciLexer, nppplugin, nppPluginUtils;

type
  TRegExGui = class(TForm)
    Label1: TLabel;
    bMatch: TButton;
    pButtons: TPanel;
    bClear: TButton;
    eMatches: TEdit;
    Label2: TLabel;
    cbIgnoreSpaces: TCheckBox;
    pMatchDetails: TPanel;
    bDetails: TButton;
    lbMatches: TListBox;
    Label3: TLabel;
    mSubMatches: TMemo;
    Label4: TLabel;
    pEditor: TPanel;
    procedure bMatchClick(Sender: TObject);
    procedure bClearClick(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure bDetailsClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lbMatchesClick(Sender: TObject);
  private
    FHandles: TNppData;
    FEditor: TScintilla;
    FEditorWasFocused: Boolean;
    FMatchList: TDetailedMatchList;
    FText: AnsiString;
    FRegEx: AnsiString;
    function GetMatchText(const AMatch: TMatch): String;
    function DetailsVisible: Boolean; inline;
    procedure BraceMatch;
    procedure ClearBraces;
    procedure SetHandles(const AHandles: TNppData);
    procedure HighlightMatches(AMatches: TDetailedMatchList);
    procedure UpdateMatchDetails;
    procedure UpdateSubMatchDetails;
    procedure UpdateActiveMatch;
    procedure ShowError(AErrMsg: String);
    procedure SetMatchDetailsVisibility(AValue: Boolean);
    procedure HandleUpdateUI(Sender: TObject);
    procedure HandleExit(Sender: TObject);
    procedure HandleEnter(Sender: TObject);
    procedure HandleModified(Sender: TObject; Position: LongInt;
      ModificationType: LongInt; Text: PAnsiChar; Length: LongInt; LinesAdded: LongInt;
      Line: LongInt; FoldLevelNow: LongInt; FoldLevelPrev: LongInt);
    function CleanRegEx(ARegEx: AnsiString; AIgnoreSpaces: Boolean): AnsiString;
  protected
    procedure WMActivate(var AMessage: TMessage); message WM_ACTIVATE;
  public
    procedure ClearMatches;
    property NppHandles: TNppData read FHandles write SetHandles;
    function WantChildKey(Child: TControl; var AMessage: TMessage): Boolean; override;
  end;

implementation
uses StrUtils;

{$R *.dfm}

procedure TRegExGui.bClearClick(Sender: TObject);
begin
  ClearMatches;
end;

procedure TRegExGui.bDetailsClick(Sender: TObject);
begin
  SetMatchDetailsVisibility(not DetailsVisible);
end;

procedure TRegExGui.bMatchClick(Sender: TObject);
var
  ErrMsg: String;
begin
  ClearMatches;
  FText := GetText(FHandles.ScintillaMain);
  FRegEx := GetText(FEditor.Handle);
  FRegEx := CleanRegEx(FRegEx, cbIgnoreSpaces.Checked);
  FMatchList := FindMatchesDetailed(FRegEx, FText, ErrMsg);

  if Assigned(FMatchList) then
    HighlightMatches(FMatchList);

  if Length(ErrMsg) > 0 then
    ShowError(ErrMsg);

  UpdateMatchDetails;
end;

procedure TRegExGui.BraceMatch;
var
  CaretPos, BracePos: Integer;
begin
  CaretPos := FEditor.GetCurrentPos;
  BracePos := FEditor.BraceMatch(CaretPos);

  if BracePos = -1 then
    CaretPos := -1;
  FEditor.BraceHighlight(CaretPos, BracePos);
end;

function TRegExGui.CleanRegEx(ARegEx: AnsiString; AIgnoreSpaces: Boolean): AnsiString;
begin
  ARegEx := AnsiString(StringReplace(String(ARegEx), #13#10, '', [rfReplaceAll]));
  if AIgnoreSpaces then
    ARegEx := AnsiString(StringReplace(String(ARegEx), ' ', '', [rfReplaceAll]));
  Result := AnsiString(ARegEx);
end;

procedure TRegExGui.HandleExit(Sender: TObject);
begin
  ClearBraces;
end;

procedure TRegExGui.HandleModified(Sender: TObject; Position,
  ModificationType: Integer; Text: PAnsiChar; Length, LinesAdded, Line,
  FoldLevelNow, FoldLevelPrev: Integer);
begin
  ClearMatches;
end;

procedure TRegExGui.ClearBraces;
begin
  FEditor.BraceHighlight(-1, -1);
end;

procedure TRegExGui.ClearMatches;
begin
  eMatches.Text := '-';
  SetLength(FText, 0);
  SetLength(FRegEx, 0);
  FreeAndNil(FMatchList);
  lbMatches.Items.Clear;
  mSubMatches.Clear;
  ClearIndicators(FHandles.ScintillaMain);
end;

function TRegExGui.DetailsVisible: Boolean;
begin
  Result := pMatchDetails.Visible;
end;

procedure TRegExGui.FormCreate(Sender: TObject);
const
  STYLE_BRACELIGHT = 34;
  SCMOD_SHIFT = 1;
begin
  SetMatchDetailsVisibility(False);

  FEditor := TScintilla.Create(Self);
  FEditor.Parent := pEditor;
  FEditor.Align := alClient;
  FEditor.OnUpdateUI := HandleUpdateUI;
  FEditor.OnExit := HandleExit;
  FEditor.OnEnter := HandleEnter;
  FEditor.OnModified := HandleModified;

  FEditor.HandleNeeded;
  FEditor.SetCodePage(CP_UTF8);
  FEditor.SetMarginWidthN(1, 0);
  FEditor.StyleSetFore(STYLE_BRACELIGHT, $000000FF);
  FEditor.StyleSetBack(STYLE_BRACELIGHT, $00FFDFDF);
  FEditor.ClearCmdKey(VK_TAB);
  FEditor.ClearCmdKey((SCMOD_SHIFT shl 16) or VK_TAB);
end;

procedure TRegExGui.FormHide(Sender: TObject);
begin
  ClearMatches;
end;

procedure TRegExGui.FormShow(Sender: TObject);
begin
  FEditor.SetFocus;
end;

function TRegExGui.GetMatchText(const AMatch: TMatch): String;
var
  ValidIndicies: Boolean;
  TextLength: Integer;
  Tmp: AnsiString;
begin
  Result := '';
  TextLength := Length(FText);
  ValidIndicies := (AMatch.StartPos >= 0) and (AMatch.EndPos >= 0)
               and (AMatch.StartPos <= TextLength) and (AMatch.EndPos <= TextLength)
               and (AMatch.StartPos < AMatch.EndPos);

  if ValidIndicies then
  begin
    SetLength(Tmp, AMatch.EndPos - AMatch.StartPos);
    Move(FText[AMatch.StartPos + 1], Tmp[1], Length(Tmp));
    Result := String(Tmp);
  end;
end;

procedure TRegExGui.HandleEnter(Sender: TObject);
begin
  BraceMatch;
end;

procedure TRegExGui.HighlightMatches(AMatches: TDetailedMatchList);
begin
  eMatches.Text := IntToStr(AMatches.Count);
  MarkMatches(FHandles.ScintillaMain, AMatches);
end;

procedure TRegExGui.lbMatchesClick(Sender: TObject);
begin
  UpdateSubMatchDetails;
  UpdateActiveMatch;
end;

procedure TRegExGui.SetHandles(const AHandles: TNppData);
begin
  FHandles := AHandles;
end;

procedure TRegExGui.SetMatchDetailsVisibility(AValue: Boolean);
const
  FLAGS = SWP_NOZORDER or SWP_NOACTIVATE;
  CAPTION = 'Details %s';
var
  R: TRect;
  Marker: Char;
  NewHeight: Integer;
begin
  if DetailsVisible = AValue then Exit;

  if AValue then
  begin
    NewHeight := Height + pMatchDetails.Height;
    Marker := '«';
  end
  else
  begin
    NewHeight := Height - pMatchDetails.Height;
    Marker := '»';
    ClearActiveMatch(NppHandles.ScintillaMain, True);
  end;

  pMatchDetails.Visible := AValue;
  bDetails.Caption := Format(CAPTION, [Marker]);

  GetWindowRect(Handle, R);
  SetWindowPos(Handle, 0, R.Left, R.Top, Width, NewHeight, FLAGS);

  UpdateMatchDetails;
end;

procedure TRegExGui.ShowError(AErrMsg: String);
begin
  ShowMessage(AErrMsg);
end;

procedure TRegExGui.UpdateActiveMatch;
var
  DetailedMatch: TDetailedMatch;
  Match: TMatch;
  MatchIndex: Integer;
begin
  ClearActiveMatch(NppHandles.ScintillaMain, True);

  MatchIndex := lbMatches.ItemIndex;
  if (MatchIndex < 0) or not Assigned(FMatchList) or (MatchIndex >= FMatchList.Count) then
    Exit;

  DetailedMatch := FMatchList.Matches[MatchIndex];
  Match.StartPos := DetailedMatch.StartPos;
  Match.EndPos := DetailedMatch.EndPos;
  MarkActiveMatch(NppHandles.ScintillaMain, Match);
  ScrollToPosition(NppHandles.ScintillaMain, Match.StartPos);
end;

procedure TRegExGui.UpdateMatchDetails;
var
  Match: TMatch;
  DetailedMatch: TDetailedMatch;
begin
  lbMatches.Clear;
  if not DetailsVisible then Exit;
  if not Assigned(FMatchList) then Exit;

  for DetailedMatch in FMatchList.Matches do
  begin
    Match.StartPos := DetailedMatch.StartPos;
    Match.EndPos := DetailedMatch.EndPos;
    lbMatches.Items.Add(GetMatchText(Match));
  end;

  if lbMatches.Count > 0 then
    lbMatches.ItemIndex := 0;

  UpdateSubMatchDetails;
  UpdateActiveMatch;
end;

procedure TRegExGui.UpdateSubMatchDetails;
const
  ENTRY = '\%d: %s';
var
  MatchIndex: Integer;
  Match: TMatch;
  DetailedMatch: TDetailedMatch;
  N: Integer;
begin
  mSubMatches.Clear;

  MatchIndex := lbMatches.ItemIndex;
  if (MatchIndex < 0) or not Assigned(FMatchList) or (MatchIndex >= FMatchList.Count) then
    Exit;

  N := 0;
  DetailedMatch := FMatchList.Matches[MatchIndex];
  for Match in DetailedMatch.SubMatches do
  begin
    Inc(N);
    mSubMatches.Lines.Add(Format(ENTRY, [N, GetMatchText(Match)]));
  end;
end;

procedure TRegExGui.HandleUpdateUI(Sender: TObject);
begin
  BraceMatch;
end;

function TRegExGui.WantChildKey(Child: TControl; var AMessage: TMessage): Boolean;
const
  KEY_DOWN = $8000;
  VK_D = Integer(AnsiChar('D'));
var
  Shifted: Boolean;
begin
  Result := ((AMessage.msg = WM_CHAR) and (AMessage.wparam = VK_TAB))
         or ((AMessage.msg = WM_KEYUP) and (
            (AMessage.WParam = VK_RETURN)
            or (AMessage.WParam = VK_DELETE)
            or (AMessage.WParam = VK_D)
            ));
  if Result then
    case AMessage.WParam of
      VK_TAB:
        begin
          Shifted := (GetKeyState(VK_SHIFT) and KEY_DOWN) > 0;
          SelectNext(TWinControl(Child), not Shifted, True)
        end;
      VK_RETURN:
        begin
          Result := (GetKeyState(VK_CONTROL) and KEY_DOWN) > 0;
          if Result then
            bMatch.Click;
        end;
      VK_DELETE:
        begin
          Result := (GetKeyState(VK_CONTROL) and KEY_DOWN) > 0;
          if Result then
            bClear.Click;
        end;
      VK_D:
        begin
          Result := (GetKeyState(VK_CONTROL) and KEY_DOWN) > 0;
          if Result then
            bDetails.Click;
        end;
    end;

  if not Result then
    Result := Child.Perform(CN_BASE + AMessage.Msg, AMessage.WParam, AMessage.LParam) <> 0;
end;

procedure TRegExGui.WMActivate(var AMessage: TMessage);
begin
  inherited;
  case AMessage.WParam of
    WA_ACTIVE, WA_CLICKACTIVE:
      begin
        if FEditorWasFocused then
          BraceMatch;
        FEditorWasFocused := False;
      end;
    WA_INACTIVE:
      begin
        ClearBraces;
        FEditorWasFocused := FEditor.Focused
      end;
  end;
end;

end.
