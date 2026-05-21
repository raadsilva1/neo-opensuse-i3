unit asset_locator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, models;

function LocateAssets(const Options: TCLIOptions; out AssetsDir, Source: string): Boolean;

implementation

function ExeDir: string;
begin
  Result := ExtractFileDir(ParamStr(0));
  if Result = '' then
    Result := GetCurrentDir;
  Result := ExpandFileName(Result);
end;

function TryDir(const Candidate: string; const LabelName: string; out AssetsDir, Source: string): Boolean;
begin
  AssetsDir := NormalizePath(Candidate);
  Source := LabelName;
  Result := DirectoryExists(AssetsDir);
end;

function LocateAssets(const Options: TCLIOptions; out AssetsDir, Source: string): Boolean;
var
  Env: string;
begin
  Result := False;
  AssetsDir := '';
  Source := '';
  if Options.AssetsDir <> '' then
    Exit(TryDir(Options.AssetsDir, '--assets-dir', AssetsDir, Source));
  Env := GetEnvironmentVariable('NEO_OPENSUSE_I3_ASSETS');
  if Env <> '' then
    Exit(TryDir(Env, 'NEO_OPENSUSE_I3_ASSETS', AssetsDir, Source));
  if TryDir(ExeDir + DirectorySeparator + 'assets', 'assets next to executable', AssetsDir, Source) then
    Exit(True);
  Result := TryDir(GetCurrentDir + DirectorySeparator + 'assets', 'assets in current directory', AssetsDir, Source);
end;

end.
