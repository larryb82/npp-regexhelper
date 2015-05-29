unit nppPluginUtils;

interface
uses scisupport;

type
  TMatch = packed record
    StartPos: Integer;
    EndPos: Integer;
  end;
  PMatch = ^TMatch;
  TMatches = array of TMatch;
  TMatchArray = array [0..MaxInt div SizeOf(TMatch) - 1] of TMatch;
  PMatchArray = ^TMatchArray;

  TDetailedMatch = record
    StartPos: Integer;
    EndPos: Integer;
    SubMatches: TMatches;
  end;
  TDetailedMatches = array of TDetailedMatch;

  TDetailedMatchList = class
  private
    FMatches: TDetailedMatches;
    function GetMatchCount: Integer;
  public
    procedure AddDetailedMatch(AOutVector: PMatchArray; AReturnValue: Integer); overload;
    procedure AddDetailedMatch(const ADetailedMatch: TDetailedMatch); overload;
    property Matches: TDetailedMatches read FMatches;
    property Count: Integer read GetMatchCount;
  end;

function GetText(ASciHandle: THandle): AnsiString;
function FindMatchesDetailed(APattern, AText: AnsiString; var ErrMsg: String): TDetailedMatchList;
procedure MarkMatches(SciHandle: THandle; MatchList: TDetailedMatchList);
procedure MarkActiveMatch(SciHandle: THandle; const Match: TMatch);
procedure ClearIndicators(SciHandle: THandle);
procedure ClearActiveMatch(SciHandle: THandle; RestorePrevious: Boolean);
procedure ScrollToPosition(SciHandle: THandle; Position: Integer);

implementation
uses Windows, pcre;

const
  INVALID_POS = -1;
  ERR_PCRE_NOT_LOADED = 'PCRE could not be loaded';

  INDICATOR_DEFAULT = 1;
  INDICATOR_ALTERNATE = 2;
  INDICATOR_ACTIVE_MATCH = 3;

var
  ActiveMatch: TMatch = (StartPos: INVALID_POS; EndPos: INVALID_POS);

function GetText(ASciHandle: THandle): AnsiString;
var
  TextLength: Integer;
  Buf: Array of Byte;
begin
  TextLength := SendMessage(ASciHandle, SCI_GETTEXTLENGTH, 0, 0);
  if TextLength > 0 then
  begin
    SetLength(Buf, TextLength + 1);
    SendMessage(ASciHandle, SCI_GETTEXT, Length(Buf), LPARAM(PAnsiChar(Buf)));
    Result := Copy(PAnsiChar(Buf), 0, TextLength);
  end
  else
    Result := '';
end;

function FindMatchesDetailed(APattern, AText: AnsiString; var ErrMsg: String): TDetailedMatchList;
const
  FLAGS: Integer = PCRE_MULTILINE or PCRE_NEWLINE_ANYCRLF;
var
  Compiled: PPCRE;
  LibErrMsg: PAnsiChar;
  LibErr: Integer;
  HasMatch, BufLength: Integer;
  Matches: array[0..299] of TMatch; // int array with 600 elements captures 199 sub-patterns
begin
  Result := nil;

  if not IsPCRELoaded then
  begin
    ErrMsg := ERR_PCRE_NOT_LOADED;
    Exit;
  end;

  BufLength := 2 * Length(Matches);
  Compiled := pcre_compile(PAnsiChar(APattern), FLAGS, @LibErrMsg, @LibErr, nil);
  if not Assigned(Compiled) then
    ErrMsg := String(LibErrMsg)
  else
    try
      Result := TDetailedMatchList.Create;
      HasMatch := pcre_exec(Compiled, nil, PAnsiChar(AText), Length(AText), 0, 0, @Matches[0], BufLength);
      while HasMatch > 0 do
      begin
        if (Matches[0].StartPos = Matches[0].EndPos) then
        begin
          Inc(Matches[0].EndPos);
          if Matches[0].EndPos >= Length(AText) then Break;
          HasMatch := pcre_exec(Compiled, nil, PAnsiChar(AText), Length(AText), Matches[0].EndPos, 0, @Matches[0], BufLength);
        end
        else
        begin
          Result.AddDetailedMatch(PMatchArray(@Matches[0]), HasMatch);
          HasMatch := pcre_exec(Compiled, nil, PAnsiChar(AText), Length(AText), Matches[0].EndPos, 0, @Matches[0], BufLength);
        end;
      end;
    finally
      CallPCREFree(Compiled);
    end;
end;

procedure ClearIndicators(SciHandle: THandle);
var
  DocLength: Integer;
begin
  DocLength := SendMessage(SciHandle, SCI_GETLENGTH, 0, 0);

  SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_DEFAULT, 0);
  SendMessage(SciHandle, SCI_SETINDICATORVALUE, 0, 0);
  SendMessage(SciHandle, SCI_INDICATORFILLRANGE, 0, DocLength);
  SendMessage(SciHandle, SCI_INDICATORCLEARRANGE, 0, DocLength);

  SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_ALTERNATE, 0);
  SendMessage(SciHandle, SCI_SETINDICATORVALUE, 0, 0);
  SendMessage(SciHandle, SCI_INDICATORFILLRANGE, 0, DocLength);
  SendMessage(SciHandle, SCI_INDICATORCLEARRANGE, 0, DocLength);

  SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_ACTIVE_MATCH, 0);
  SendMessage(SciHandle, SCI_SETINDICATORVALUE, 0, 0);
  SendMessage(SciHandle, SCI_INDICATORFILLRANGE, 0, DocLength);
  SendMessage(SciHandle, SCI_INDICATORCLEARRANGE, 0, DocLength);

  ActiveMatch.StartPos := INVALID_POS;
  ActiveMatch.EndPos := INVALID_POS;
end;

procedure ClearActiveMatch(SciHandle: THandle; RestorePrevious: Boolean);
var
  OldIndicator: Integer;
begin
  if (ActiveMatch.StartPos = INVALID_POS) or (ActiveMatch.EndPos = INVALID_POS) then Exit;

  OldIndicator := SendMessage(SciHandle, SCI_INDICATORVALUEAT, INDICATOR_ACTIVE_MATCH, ActiveMatch.StartPos);
  SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_ACTIVE_MATCH, 0);
  SendMessage(SciHandle, SCI_INDICATORCLEARRANGE, ActiveMatch.StartPos, ActiveMatch.EndPos - ActiveMatch.StartPos);

  if RestorePrevious then
  begin
    SendMessage(SciHandle, SCI_SETINDICATORCURRENT, OldIndicator, 0);
    SendMessage(SciHandle, SCI_SETINDICATORVALUE, OldIndicator, 0);
    SendMessage(SciHandle, SCI_INDICATORFILLRANGE, ActiveMatch.StartPos, ActiveMatch.EndPos - ActiveMatch.StartPos);
  end;

  ActiveMatch.StartPos := INVALID_POS;
  ActiveMatch.EndPos := INVALID_POS;
end;

procedure ScrollToPosition(SciHandle: THandle; Position: Integer);
var
  TargetLine: Integer;
begin
  TargetLine := SendMessage(SciHandle, SCI_LINEFROMPOSITION, Position, 0);
  SendMessage(SciHandle, SCI_GOTOLINE, TargetLine, 0);
end;

procedure MarkMatches(SciHandle: THandle; MatchList: TDetailedMatchList);
var
  Match: TDetailedMatch;
  B: Boolean;
begin
  SendMessage(SciHandle, SCI_INDICSETSTYLE, INDICATOR_DEFAULT, INDIC_ROUNDBOX);
  SendMessage(SciHandle, SCI_INDICSETFORE, INDICATOR_DEFAULT, $FF1111);
  SendMessage(SciHandle, SCI_INDICSETSTYLE, INDICATOR_ALTERNATE, INDIC_ROUNDBOX);
  SendMessage(SciHandle, SCI_INDICSETFORE, INDICATOR_ALTERNATE, $1111FF);

  B := false;
  for Match in MatchList.Matches do
  begin
    if B then
    begin
      SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_DEFAULT, 0);
      SendMessage(SciHandle, SCI_SETINDICATORVALUE, INDICATOR_DEFAULT, 0);
    end
    else
    begin
      SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_ALTERNATE, 0);
      SendMessage(SciHandle, SCI_SETINDICATORVALUE, INDICATOR_ALTERNATE, 0);
    end;
    SendMessage(SciHandle, SCI_INDICATORFILLRANGE, Match.StartPos, Match.EndPos - Match.StartPos);
    B := not B;
  end;
end;

procedure MarkActiveMatch(SciHandle: THandle; const Match: TMatch);
var
  OldIndicator: Integer;
begin
  OldIndicator := 0;
  if INDICATOR_DEFAULT = SendMessage(SciHandle, SCI_INDICATORVALUEAT, INDICATOR_DEFAULT, Match.StartPos) then
  begin
    OldIndicator := INDICATOR_DEFAULT;
    SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_DEFAULT, 0);
    SendMessage(SciHandle, SCI_INDICATORCLEARRANGE, Match.StartPos, Match.EndPos - Match.StartPos);
  end
  else if INDICATOR_ALTERNATE = SendMessage(SciHandle, SCI_INDICATORVALUEAT, INDICATOR_ALTERNATE, Match.StartPos) then
  begin
    OldIndicator := INDICATOR_ALTERNATE;
    SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_ALTERNATE, 0);
    SendMessage(SciHandle, SCI_INDICATORCLEARRANGE, Match.StartPos, Match.EndPos - Match.StartPos);
  end;

  SendMessage(SciHandle, SCI_INDICSETSTYLE, INDICATOR_ACTIVE_MATCH, INDIC_BOX);
  SendMessage(SciHandle, SCI_INDICSETFORE, INDICATOR_ACTIVE_MATCH, $007F00);

  SendMessage(SciHandle, SCI_SETINDICATORCURRENT, INDICATOR_ACTIVE_MATCH, 0);
  SendMessage(SciHandle, SCI_SETINDICATORVALUE, OldIndicator, 0);
  SendMessage(SciHandle, SCI_INDICATORFILLRANGE, Match.StartPos, Match.EndPos - Match.StartPos);

  ActiveMatch := Match;
end;

{ TDetailedMatchList }

procedure TDetailedMatchList.AddDetailedMatch(AOutVector: PMatchArray; AReturnValue: Integer);
var
  DetailedMatch: TDetailedMatch;
  I: Integer;
begin
  if AReturnValue < 1 then Exit;

  DetailedMatch.StartPos := AOutVector[0].StartPos;
  DetailedMatch.EndPos := AOutVector[0].EndPos;
  SetLength(DetailedMatch.SubMatches, AReturnValue - 1);
  for I := 1 to AReturnValue - 1 do
    DetailedMatch.SubMatches[I-1] := AOutVector[I];

  AddDetailedMatch(DetailedMatch);
end;

procedure TDetailedMatchList.AddDetailedMatch(
  const ADetailedMatch: TDetailedMatch);
var
  N: Integer;
begin
  N := Length(FMatches);
  SetLength(FMatches, N + 1);
  FMatches[N] := ADetailedMatch;
end;

function TDetailedMatchList.GetMatchCount: Integer;
begin
  Result := Length(FMatches);
end;

initialization
  LoadPCRE;

finalization
  UnloadPCRE;

end.
