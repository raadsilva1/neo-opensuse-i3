unit rollback_manager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, logger;

function ListBackups(Log: TLogger): Boolean;
function RollbackLatest(Log: TLogger): Boolean;

implementation

uses
  Classes, BaseUnix, models, process_runner;

function ParseOctMode(const S: string): LongInt;
var
  I, D: Integer;
begin
  Result := 0;
  for I := 1 to Length(S) do
    if S[I] in ['0'..'7'] then
    begin
      D := Ord(S[I]) - Ord('0');
      Result := (Result shl 3) + D;
    end;
end;

function CopyOverwrite(const Source, Dest: string; UID, GID, Mode: LongInt): Boolean;
var
  InF, OutF: TFileStream;
begin
  Result := False;
  try
    ForceDirectories(ExtractFileDir(Dest));
    InF := TFileStream.Create(Source, fmOpenRead or fmShareDenyWrite);
    try
      OutF := TFileStream.Create(Dest, fmCreate);
      try
        OutF.CopyFrom(InF, 0);
      finally
        OutF.Free;
      end;
    finally
      InF.Free;
    end;
    if UID >= 0 then fpChown(PChar(Dest), UID, GID);
    if Mode > 0 then fpChmod(PChar(Dest), Mode);
    Result := True;
  except
    Result := False;
  end;
end;

function ListBackups(Log: TLogger): Boolean;
var
  R: TCommandResult;
begin
  R := RunCommand('/usr/bin/env', ['sh', '-c', 'find /var/lib/neo-opensuse-i3 "$HOME/.local/share/neo-opensuse-i3" -path ''*/backups/*'' -maxdepth 4 -type f -name manifest.tsv 2>/dev/null | sort']);
  if Trim(R.Output) = '' then
    Writeln('No neo-opensuse-i3 backup manifests found.')
  else
    Write(R.Output);
  if Assigned(Log) then Log.Info('listed backups');
  Result := True;
end;

function LatestManifest: string;
var
  R: TCommandResult;
begin
  R := RunCommand('/usr/bin/env', ['sh', '-c', 'find /var/lib/neo-opensuse-i3 "$HOME/.local/share/neo-opensuse-i3" -path ''*/backups/*'' -maxdepth 4 -type f -name manifest.tsv 2>/dev/null | sort | tail -n 1']);
  Result := Trim(R.Output);
end;

function RollbackLatest(Log: TLogger): Boolean;
var
  Manifest: string;
  Lines, Parts: TStringList;
  I: Integer;
  OriginalPath, BackupPath, Operation: string;
  BeforeUID, BeforeGID, BeforeMode: LongInt;
begin
  Result := False;
  Manifest := LatestManifest;
  if Manifest = '' then
  begin
    if Assigned(Log) then Log.Error('no backup manifest found for rollback');
    Exit;
  end;
  Lines := TStringList.Create;
  Parts := TStringList.Create;
  try
    Lines.LoadFromFile(Manifest);
    Parts.Delimiter := #9;
    Parts.StrictDelimiter := True;
    for I := Lines.Count - 1 downto 0 do
    begin
      Parts.DelimitedText := Lines[I];
      if Parts.Count < 2 then Continue;
      OriginalPath := Parts[0];
      BackupPath := Parts[1];
      Operation := '';
      BeforeUID := -1;
      BeforeGID := -1;
      BeforeMode := 0;
      if Parts.Count >= 13 then
      begin
        Operation := Parts[2];
        BeforeUID := StrToIntDef(Parts[4], -1);
        BeforeGID := StrToIntDef(Parts[5], -1);
        BeforeMode := ParseOctMode(Parts[8]);
      end;
      if (Operation = 'create-file') and (BackupPath = '') then
      begin
        if FileExists(OriginalPath) and (not DeleteFile(OriginalPath)) then
        begin
          if Assigned(Log) then Log.Error('rollback failed to remove created file ' + OriginalPath);
          Exit(False);
        end;
        if Assigned(Log) then Log.Info('removed created file ' + OriginalPath);
        Continue;
      end;
      if (BackupPath <> '') and FileExists(BackupPath) then
      begin
        if not CopyOverwrite(BackupPath, OriginalPath, BeforeUID, BeforeGID, BeforeMode) then
        begin
          if Assigned(Log) then Log.Error('rollback failed for ' + OriginalPath);
          Exit(False);
        end;
        if Assigned(Log) then Log.Info('restored ' + OriginalPath + ' from ' + BackupPath);
      end;
    end;
    Result := True;
  finally
    Parts.Free;
    Lines.Free;
  end;
end;

end.
