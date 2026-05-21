unit os_detect;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, logger;

type
  TOSInfo = record
    ID: string;
    IDLike: string;
    PrettyName: string;
    VersionID: string;
    IsTumbleweed: Boolean;
    IsOpenSUSE: Boolean;
  end;

function ReadOSInfo: TOSInfo;
function ValidateOS(const Info: TOSInfo; Force: Boolean; Log: TLogger; out Message: string): Boolean;

implementation

function Unquote(const S: string): string;
begin
  Result := Trim(S);
  if (Length(Result) >= 2) and (Result[1] = '"') and (Result[Length(Result)] = '"') then
    Result := Copy(Result, 2, Length(Result) - 2);
end;

function ReadOSInfo: TOSInfo;
var
  Lines: TStringList;
  I, P: Integer;
  K, V: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  if not FileExists('/etc/os-release') then Exit;
  Lines := TStringList.Create;
  try
    Lines.LoadFromFile('/etc/os-release');
    for I := 0 to Lines.Count - 1 do
    begin
      P := Pos('=', Lines[I]);
      if P < 1 then Continue;
      K := Copy(Lines[I], 1, P - 1);
      V := Unquote(Copy(Lines[I], P + 1, MaxInt));
      if K = 'ID' then Result.ID := V
      else if K = 'ID_LIKE' then Result.IDLike := V
      else if K = 'PRETTY_NAME' then Result.PrettyName := V
      else if K = 'VERSION_ID' then Result.VersionID := V;
    end;
  finally
    Lines.Free;
  end;
  Result.IsTumbleweed := Result.ID = 'opensuse-tumbleweed';
  Result.IsOpenSUSE := Result.IsTumbleweed or (Pos('opensuse', Result.ID) > 0) or (Pos('opensuse', Result.IDLike) > 0);
end;

function ValidateOS(const Info: TOSInfo; Force: Boolean; Log: TLogger; out Message: string): Boolean;
begin
  Message := Info.PrettyName;
  if Assigned(Log) then
    Log.Info('OS detected: ' + Info.PrettyName + ' id=' + Info.ID + ' version=' + Info.VersionID);
  Result := Info.IsTumbleweed;
  if Result then Exit;
  if Info.IsOpenSUSE then
    Message := 'openSUSE variant detected but not Tumbleweed: ' + Info.PrettyName
  else
    Message := 'unsupported OS: ' + Info.PrettyName;
  if Force then
  begin
    if Assigned(Log) then Log.Warn(Message + '; continuing because --force was set');
    Result := True;
  end
  else if Assigned(Log) then
    Log.Error(Message);
end;

end.
