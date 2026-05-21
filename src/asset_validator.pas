unit asset_validator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, BaseUnix, models, logger;

function ValidateAssets(const AssetsDir, Theme: string; Log: TLogger; out Missing: TStringArray; out Warning: string): Boolean;

implementation

procedure RequireFile(const AssetsDir, RelPath: string; var Missing: TStringArray);
begin
  if (not FileExists(AssetsDir + DirectorySeparator + RelPath)) and (not ContainsString(Missing, RelPath)) then
    AddString(Missing, RelPath);
end;

function HasWallpaper(const AssetsDir: string): Boolean;
var
  SR: TSearchRec;
  Dir: string;
begin
  Result := False;
  Dir := AssetsDir + DirectorySeparator + 'wallpapers';
  if FindFirst(Dir + DirectorySeparator + '*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name <> '.') and (SR.Name <> '..') and ((SR.Attr and faDirectory) = 0) then
      begin
        Result := True;
        Break;
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
  end;
end;

function ValidateAssets(const AssetsDir, Theme: string; Log: TLogger; out Missing: TStringArray; out Warning: string): Boolean;
var
  Lbemenu: string;
begin
  SetLength(Missing, 0);
  Warning := '';
  RequireFile(AssetsDir, 'i3/config', Missing);
  RequireFile(AssetsDir, 'bin/lbemenu', Missing);
  RequireFile(AssetsDir, 'kitty/kitty.conf', Missing);
  RequireFile(AssetsDir, 'kitty/themes/Emerald-Night.conf', Missing);
  RequireFile(AssetsDir, 'kitty/themes/Forest-Moss.conf', Missing);
  RequireFile(AssetsDir, 'kitty/themes/Sage-Light.conf', Missing);
  RequireFile(AssetsDir, 'kitty/themes/' + Theme + '.conf', Missing);
  if not DirectoryExists(AssetsDir + DirectorySeparator + 'wallpapers') then
    AddString(Missing, 'wallpapers/')
  else if not HasWallpaper(AssetsDir) then
    AddString(Missing, 'wallpapers/*');
  Lbemenu := AssetsDir + DirectorySeparator + 'bin' + DirectorySeparator + 'lbemenu';
  if FileExists(Lbemenu) and (fpAccess(PChar(Lbemenu), X_OK) <> 0) then
    Warning := 'assets/bin/lbemenu is not executable; release packaging will chmod it';
  Result := Length(Missing) = 0;
  if Assigned(Log) then
  begin
    Log.Info('asset path: ' + AssetsDir);
    if Result then Log.Info('asset validation passed')
    else Log.Error('asset validation failed: ' + JoinStrings(Missing, ', '));
    if Warning <> '' then Log.Warn(Warning);
  end;
end;

end.
