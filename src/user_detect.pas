unit user_detect;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, models, logger;

function DetectTargetUsers(const Options: TCLIOptions; Log: TLogger): TUserArray;

implementation

uses
  process_runner;

function ShellAllowed(const Shell: string): Boolean;
begin
  Result := (Shell <> '') and (Pos('nologin', Shell) = 0) and (Pos('false', Shell) = 0);
end;

function IsSudoCapable(const UserName: string): Boolean;
var
  R: TCommandResult;
begin
  R := RunCommand('/usr/bin/env', ['id', '-nG', UserName]);
  Result := (R.ExitCode = 0) and ((Pos(' wheel ', ' ' + R.Output + ' ') > 0) or (Pos(' sudo ', ' ' + R.Output + ' ') > 0));
  if not Result then
  begin
    R := RunCommand('/usr/bin/env', ['sh', '-c', 'grep -RqsE ''^[[:space:]]*' + ShellQuote(UserName) + '[[:space:]]'' /etc/sudoers /etc/sudoers.d 2>/dev/null']);
    Result := R.ExitCode = 0;
  end;
end;

procedure AddUser(var Users: TUserArray; const U: TUserInfo);
begin
  SetLength(Users, Length(Users) + 1);
  Users[High(Users)] := U;
end;

function FindUser(const Name: string; out U: TUserInfo): Boolean;
var
  R: TCommandResult;
  Parts: TStringList;
begin
  Result := False;
  FillChar(U, SizeOf(U), 0);
  R := RunCommand('/usr/bin/env', ['getent', 'passwd', Name]);
  if R.ExitCode <> 0 then Exit;
  Parts := TStringList.Create;
  try
    Parts.Delimiter := ':';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := Trim(R.Output);
    if Parts.Count < 7 then Exit;
    U.Name := Parts[0];
    U.UID := StrToIntDef(Parts[2], -1);
    U.GID := StrToIntDef(Parts[3], -1);
    U.Home := Parts[5];
    U.Shell := Parts[6];
    Result := U.Name <> '';
  finally
    Parts.Free;
  end;
end;

function DetectTargetUsers(const Options: TCLIOptions; Log: TLogger): TUserArray;
var
  R: TCommandResult;
  Lines, Parts: TStringList;
  I: Integer;
  U: TUserInfo;
begin
  SetLength(Result, 0);
  if Length(Options.Users) > 0 then
  begin
    for I := 0 to High(Options.Users) do
      if FindUser(Options.Users[I], U) and not ContainsString(Options.ExcludedUsers, U.Name) then
      begin
        AddUser(Result, U);
        if Assigned(Log) then Log.Info('selected explicit user: ' + U.Name);
      end
      else if Assigned(Log) then Log.Warn('requested user not found or excluded: ' + Options.Users[I]);
    Exit;
  end;

  R := RunCommand('/usr/bin/env', ['getent', 'passwd']);
  if R.ExitCode <> 0 then
  begin
    if Assigned(Log) then Log.Error('getent passwd failed: ' + R.Output);
    Exit;
  end;
  Lines := TStringList.Create;
  Parts := TStringList.Create;
  try
    Lines.Text := R.Output;
    Parts.Delimiter := ':';
    Parts.StrictDelimiter := True;
    for I := 0 to Lines.Count - 1 do
    begin
      Parts.DelimitedText := Lines[I];
      if Parts.Count < 7 then Continue;
      U.Name := Parts[0];
      U.UID := StrToIntDef(Parts[2], -1);
      U.GID := StrToIntDef(Parts[3], -1);
      U.Home := Parts[5];
      U.Shell := Parts[6];
      if (U.Name = 'root') or ContainsString(Options.ExcludedUsers, U.Name) then Continue;
      if (U.UID < 1000) or not DirectoryExists(U.Home) or not ShellAllowed(U.Shell) then Continue;
      if IsSudoCapable(U.Name) then
      begin
        AddUser(Result, U);
        if Assigned(Log) then Log.Info('target user detected: ' + U.Name + ' uid=' + IntToStr(U.UID));
      end;
    end;
  finally
    Parts.Free;
    Lines.Free;
  end;
end;

end.
