unit models;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TStringArray = array of string;

  TInstallXinitrcMode = (xmAlways, xmIfNoDisplayManager, xmNever);
  TNvidiaPolicy = (npNouveau, npProprietaryPrompt, npSkip);

  TCLIOptions = record
    ShowHelp: Boolean;
    ShowVersion: Boolean;
    DryRun: Boolean;
    Plain: Boolean;
    Unattended: Boolean;
    Force: Boolean;
    Rollback: Boolean;
    ListBackups: Boolean;
    AllSudoUsers: Boolean;
    AssetsDir: string;
    Theme: string;
    LogFile: string;
    InstallXinitrc: TInstallXinitrcMode;
    NvidiaPolicy: TNvidiaPolicy;
    Users: TStringArray;
    ExcludedUsers: TStringArray;
  end;

  TCommandResult = record
    ExitCode: Integer;
    Output: string;
  end;

  TUserInfo = record
    Name: string;
    UID: LongInt;
    GID: LongInt;
    Home: string;
    Shell: string;
  end;

  TUserArray = array of TUserInfo;

  TPackageDecision = record
    Name: string;
    GroupName: string;
    Installed: Boolean;
    Candidate: Boolean;
    Required: Boolean;
    Selected: Boolean;
    Reason: string;
  end;

  TPackageDecisionArray = array of TPackageDecision;

procedure AddString(var Arr: TStringArray; const Value: string);
function ContainsString(const Arr: TStringArray; const Value: string): Boolean;
function JoinStrings(const Arr: TStringArray; const Sep: string): string;
function BoolText(Value: Boolean): string;
function NormalizePath(const Path: string): string;
function ShellQuote(const S: string): string;

implementation

procedure AddString(var Arr: TStringArray; const Value: string);
begin
  SetLength(Arr, Length(Arr) + 1);
  Arr[High(Arr)] := Value;
end;

function ContainsString(const Arr: TStringArray; const Value: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Arr) do
    if Arr[I] = Value then
      Exit(True);
end;

function JoinStrings(const Arr: TStringArray; const Sep: string): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Arr) do
  begin
    if I > 0 then
      Result := Result + Sep;
    Result := Result + Arr[I];
  end;
end;

function BoolText(Value: Boolean): string;
begin
  if Value then
    Result := 'yes'
  else
    Result := 'no';
end;

function NormalizePath(const Path: string): string;
begin
  if Path = '' then
    Exit('');
  Result := ExpandFileName(Path);
  while (Length(Result) > 1) and (Result[Length(Result)] = DirectorySeparator) do
    Delete(Result, Length(Result), 1);
end;

function ShellQuote(const S: string): string;
begin
  Result := '''' + StringReplace(S, '''', '''"''"''', [rfReplaceAll]) + '''';
end;

end.
