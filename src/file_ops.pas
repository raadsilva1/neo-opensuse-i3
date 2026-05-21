unit file_ops;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BaseUnix, ctypes, models, logger;

type
  TFileMeta = record
    Exists: Boolean;
    UID: LongInt;
    GID: LongInt;
    Mode: LongInt;
  end;

  TFileOpResult = record
    Changed: Boolean;
    BackupPath: string;
    Message: string;
  end;

function EnsureDirOwned(const Path: string; UID, GID: LongInt; Mode: LongInt; DryRun: Boolean; Log: TLogger): Boolean;
function InstallFileAtomic(const Source, Dest, BackupRoot, OwnerName: string; UID, GID: LongInt; Mode: LongInt; DryRun: Boolean; Log: TLogger; out R: TFileOpResult): Boolean;
function WriteTextAtomic(const Content, Dest, BackupRoot, OwnerName: string; UID, GID: LongInt; Mode: LongInt; DryRun: Boolean; Log: TLogger; out R: TFileOpResult): Boolean;
function CopyTreeFiles(const SourceDir, DestDir, BackupRoot, OwnerName: string; UID, GID: LongInt; Mode: LongInt; DryRun: Boolean; Log: TLogger): Boolean;
function SanitizePath(const Path: string): string;

implementation

uses
  constants, checksum;

function fsync(fd: cint): cint; cdecl; external 'c' name 'fsync';

function ReadFileMeta(const Path: string): TFileMeta;
var
  St: Stat;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Exists := fpStat(PChar(Path), St) = 0;
  if Result.Exists then
  begin
    Result.UID := St.st_uid;
    Result.GID := St.st_gid;
    Result.Mode := St.st_mode and &7777;
  end
  else
  begin
    Result.UID := -1;
    Result.GID := -1;
    Result.Mode := 0;
  end;
end;

function OctMode(Mode: LongInt): string;
const
  Digits: array[0..7] of Char = ('0','1','2','3','4','5','6','7');
begin
  Result := Digits[(Mode shr 9) and 7] + Digits[(Mode shr 6) and 7] +
    Digits[(Mode shr 3) and 7] + Digits[Mode and 7];
end;

function SanitizePath(const Path: string): string;
var
  I: Integer;
begin
  Result := Path;
  for I := 1 to Length(Result) do
    if not (Result[I] in ['a'..'z', 'A'..'Z', '0'..'9', '.', '-', '_']) then
      Result[I] := '_';
end;

function EnsureDirOwned(const Path: string; UID, GID: LongInt; Mode: LongInt; DryRun: Boolean; Log: TLogger): Boolean;
begin
  if DirectoryExists(Path) then
    Result := True
  else if DryRun then
    Result := True
  else
    Result := ForceDirectories(Path);
  if Result and not DryRun then
  begin
    fpChmod(PChar(Path), Mode);
    if UID >= 0 then fpChown(PChar(Path), UID, GID);
  end;
  if Assigned(Log) then
    if Result then Log.Info('directory ready: ' + Path)
    else Log.Error('failed to create directory: ' + Path);
end;

function SameFileContent(const A, B: string): Boolean;
begin
  Result := FileExists(A) and FileExists(B) and (SHA256File(A) = SHA256File(B));
end;

procedure AppendManifest(const BackupRoot, Original, Backup, Operation, OwnerName: string; const BeforeMeta, AfterMeta: TFileMeta; const BeforeSum, AfterSum, Status: string);
var
  F: TextFile;
  Path: string;
begin
  if BackupRoot = '' then Exit;
  ForceDirectories(BackupRoot);
  if AfterMeta.UID >= 0 then fpChown(PChar(BackupRoot), AfterMeta.UID, AfterMeta.GID);
  Path := BackupRoot + DirectorySeparator + 'manifest.tsv';
  AssignFile(F, Path);
  if FileExists(Path) then Append(F) else Rewrite(F);
  Writeln(F, Original, #9, Backup, #9, Operation, #9, OwnerName, #9,
    BeforeMeta.UID, #9, BeforeMeta.GID, #9, AfterMeta.UID, #9, AfterMeta.GID, #9,
    OctMode(BeforeMeta.Mode), #9, OctMode(AfterMeta.Mode), #9, BeforeSum, #9, AfterSum, #9,
    FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now), #9, Status);
  CloseFile(F);
  if AfterMeta.UID >= 0 then fpChown(PChar(Path), AfterMeta.UID, AfterMeta.GID);
end;

function BackupExisting(const Dest, BackupRoot: string; UID, GID: LongInt; out BackupPath: string; Log: TLogger): Boolean;
var
  InF, OutF: TFileStream;
begin
  BackupPath := '';
  if not FileExists(Dest) then Exit(True);
  if BackupRoot = '' then Exit(True);
  if not ForceDirectories(BackupRoot) then Exit(False);
  if UID >= 0 then fpChown(PChar(BackupRoot), UID, GID);
  BackupPath := BackupRoot + DirectorySeparator + SanitizePath(Dest);
  while FileExists(BackupPath) do
    BackupPath := BackupPath + '.older';
  try
    InF := TFileStream.Create(Dest, fmOpenRead or fmShareDenyWrite);
    try
      OutF := TFileStream.Create(BackupPath, fmCreate);
      try
        OutF.CopyFrom(InF, 0);
        fsync(OutF.Handle);
      finally
        OutF.Free;
      end;
    finally
      InF.Free;
    end;
    if UID >= 0 then fpChown(PChar(BackupPath), UID, GID);
    Result := True;
  except
    Result := False;
  end;
  if Assigned(Log) then
    if Result then Log.Info('backup created: ' + Dest + ' -> ' + BackupPath)
    else Log.Error('backup failed: ' + Dest);
end;

function CopyFileAtomicLow(const Source, Dest: string; UID, GID: LongInt; Mode: LongInt): Boolean;
var
  InF, OutF: TFileStream;
  Tmp: string;
begin
  Result := False;
  ForceDirectories(ExtractFileDir(Dest));
  Tmp := Dest + '.tmp.' + IntToStr(GetProcessID);
  InF := TFileStream.Create(Source, fmOpenRead or fmShareDenyWrite);
  try
    OutF := TFileStream.Create(Tmp, fmCreate);
    try
      OutF.CopyFrom(InF, 0);
      fsync(OutF.Handle);
    finally
      OutF.Free;
    end;
  finally
    InF.Free;
  end;
  if UID >= 0 then fpChown(PChar(Tmp), UID, GID);
  fpChmod(PChar(Tmp), Mode);
  Result := RenameFile(Tmp, Dest);
  if not Result and FileExists(Tmp) then DeleteFile(Tmp);
end;

function WriteTextAtomicLow(const Content, Dest: string; UID, GID: LongInt; Mode: LongInt): Boolean;
var
  OutF: TFileStream;
  Tmp: string;
  S: string;
begin
  Result := False;
  ForceDirectories(ExtractFileDir(Dest));
  Tmp := Dest + '.tmp.' + IntToStr(GetProcessID);
  S := Content;
  OutF := TFileStream.Create(Tmp, fmCreate);
  try
    if Length(S) > 0 then
      OutF.WriteBuffer(S[1], Length(S));
    fsync(OutF.Handle);
  finally
    OutF.Free;
  end;
  if UID >= 0 then fpChown(PChar(Tmp), UID, GID);
  fpChmod(PChar(Tmp), Mode);
  Result := RenameFile(Tmp, Dest);
  if not Result and FileExists(Tmp) then DeleteFile(Tmp);
end;

function InstallFileAtomic(const Source, Dest, BackupRoot, OwnerName: string; UID, GID: LongInt; Mode: LongInt; DryRun: Boolean; Log: TLogger; out R: TFileOpResult): Boolean;
var
  BeforeSum, AfterSum: string;
  BeforeMeta, AfterMeta: TFileMeta;
  Operation: string;
begin
  R.Changed := False;
  R.BackupPath := '';
  R.Message := '';
  if not FileExists(Source) then
  begin
    R.Message := 'source missing: ' + Source;
    if Assigned(Log) then Log.Error(R.Message);
    Exit(False);
  end;
  BeforeMeta := ReadFileMeta(Dest);
  BeforeSum := SHA256File(Dest);
  if SameFileContent(Source, Dest) then
  begin
    if not DryRun then
    begin
      if UID >= 0 then fpChown(PChar(Dest), UID, GID);
      fpChmod(PChar(Dest), Mode);
    end;
    R.Message := 'already configured: ' + Dest;
    if Assigned(Log) then Log.Info(R.Message);
    Exit(True);
  end;
  R.Changed := True;
  if BeforeMeta.Exists then Operation := 'update-file' else Operation := 'create-file';
  if DryRun then
  begin
    R.Message := 'dry-run would install: ' + Dest;
    if Assigned(Log) then Log.Info(R.Message);
    Exit(True);
  end;
  if not BackupExisting(Dest, BackupRoot, UID, GID, R.BackupPath, Log) then Exit(False);
  if not CopyFileAtomicLow(Source, Dest, UID, GID, Mode) then Exit(False);
  if UID >= 0 then fpChown(PChar(Dest), UID, GID);
  fpChmod(PChar(Dest), Mode);
  AfterMeta := ReadFileMeta(Dest);
  AfterSum := SHA256File(Dest);
  AppendManifest(BackupRoot, Dest, R.BackupPath, Operation, OwnerName, BeforeMeta, AfterMeta, BeforeSum, AfterSum, 'success');
  R.Message := 'installed: ' + Dest;
  if Assigned(Log) then Log.Info(R.Message);
  Result := True;
end;

function WriteTextAtomic(const Content, Dest, BackupRoot, OwnerName: string; UID, GID: LongInt; Mode: LongInt; DryRun: Boolean; Log: TLogger; out R: TFileOpResult): Boolean;
var
  TmpSource: string;
begin
  TmpSource := GetTempDir(False) + AppName + '-text-' + IntToStr(GetProcessID);
  if not WriteTextAtomicLow(Content, TmpSource, -1, -1, &600) then
  begin
    R.Message := 'failed to stage text content';
    Exit(False);
  end;
  try
    Result := InstallFileAtomic(TmpSource, Dest, BackupRoot, OwnerName, UID, GID, Mode, DryRun, Log, R);
  finally
    if FileExists(TmpSource) then DeleteFile(TmpSource);
  end;
end;

function CopyTreeFiles(const SourceDir, DestDir, BackupRoot, OwnerName: string; UID, GID: LongInt; Mode: LongInt; DryRun: Boolean; Log: TLogger): Boolean;
var
  SR: TSearchRec;
  R: TFileOpResult;
begin
  Result := True;
  if FindFirst(SourceDir + DirectorySeparator + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then Continue;
      if (SR.Attr and faDirectory) = 0 then
        Result := InstallFileAtomic(SourceDir + DirectorySeparator + SR.Name, DestDir + DirectorySeparator + SR.Name,
          BackupRoot, OwnerName, UID, GID, Mode, DryRun, Log, R) and Result;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

end.
