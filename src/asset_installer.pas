unit asset_installer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, models, logger;

function InstallAssetsForUsers(const AssetsDir, BackupStamp: string; const Users: TUserArray; InstallXinitrc: Boolean; DryRun: Boolean; Log: TLogger): Boolean;
function InstallSystemAssets(const AssetsDir, BackupRoot: string; DryRun: Boolean; Log: TLogger): Boolean;

implementation

uses
  BaseUnix, file_ops, xinitrc_manager;

function UserBackupRoot(const U: TUserInfo; const Stamp: string): string;
begin
  Result := U.Home + DirectorySeparator + '.local/share/neo-opensuse-i3/backups/' + Stamp;
end;

function InstallWallpaperTree(const AssetsDir: string; const U: TUserInfo; const BackupRoot: string; DryRun: Boolean; Log: TLogger): Boolean;
begin
  Result := CopyTreeFiles(AssetsDir + DirectorySeparator + 'wallpapers',
    U.Home + DirectorySeparator + 'Pictures/Wallpapers', BackupRoot, U.Name, U.UID, U.GID, &644, DryRun, Log);
end;

function InstallAssetsForUsers(const AssetsDir, BackupStamp: string; const Users: TUserArray; InstallXinitrc: Boolean; DryRun: Boolean; Log: TLogger): Boolean;
var
  I: Integer;
  U: TUserInfo;
  Root: string;
  R: TFileOpResult;
begin
  Result := True;
  for I := 0 to High(Users) do
  begin
    U := Users[I];
    Root := UserBackupRoot(U, BackupStamp);
    Result := EnsureDirOwned(U.Home + '/.config/i3', U.UID, U.GID, &755, DryRun, Log) and Result;
    Result := EnsureDirOwned(U.Home + '/.config/kitty/themes', U.UID, U.GID, &755, DryRun, Log) and Result;
    Result := EnsureDirOwned(U.Home + '/.local/bin', U.UID, U.GID, &755, DryRun, Log) and Result;
    Result := EnsureDirOwned(U.Home + '/Pictures/Screenshots', U.UID, U.GID, &755, DryRun, Log) and Result;
    Result := EnsureDirOwned(U.Home + '/Pictures/Wallpapers', U.UID, U.GID, &755, DryRun, Log) and Result;
    Result := InstallFileAtomic(AssetsDir + '/i3/config', U.Home + '/.config/i3/config', Root, U.Name, U.UID, U.GID, &644, DryRun, Log, R) and Result;
    Result := InstallFileAtomic(AssetsDir + '/kitty/kitty.conf', U.Home + '/.config/kitty/kitty.conf', Root, U.Name, U.UID, U.GID, &644, DryRun, Log, R) and Result;
    Result := CopyTreeFiles(AssetsDir + '/kitty/themes', U.Home + '/.config/kitty/themes', Root, U.Name, U.UID, U.GID, &644, DryRun, Log) and Result;
    Result := InstallFileAtomic(AssetsDir + '/bin/lbemenu', U.Home + '/.local/bin/lbemenu', Root, U.Name, U.UID, U.GID, &755, DryRun, Log, R) and Result;
    Result := InstallWallpaperTree(AssetsDir, U, Root, DryRun, Log) and Result;
    if InstallXinitrc then
      Result := InstallXinitrcForUser(U, Root, DryRun, Log) and Result;
    if not DryRun then
      fpChown(PChar(U.Home + '/.local/share/neo-opensuse-i3'), U.UID, U.GID);
  end;
end;

function InstallSystemAssets(const AssetsDir, BackupRoot: string; DryRun: Boolean; Log: TLogger): Boolean;
var
  R: TFileOpResult;
begin
  Result := InstallFileAtomic(AssetsDir + '/bin/lbemenu', '/usr/local/bin/lbemenu',
    BackupRoot, 'root', 0, 0, &755, DryRun, Log, R);
  if (not Result) and Assigned(Log) then
    Log.Warn('system lbemenu install failed; per-user ~/.local/bin/lbemenu remains available');
end;

end.
