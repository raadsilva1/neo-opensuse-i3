unit xinitrc_manager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, models, display_manager, logger;

function ShouldInstallXinitrc(Mode: TInstallXinitrcMode; const DM: TDisplayManagerInfo; Wayland: Boolean): Boolean;
function InstallXinitrcForUser(const U: TUserInfo; const BackupRoot: string; DryRun: Boolean; Log: TLogger): Boolean;

implementation

uses
  file_ops;

const
  XinitrcContent =
    '#!/bin/sh' + LineEnding +
    'exec /usr/local/bin/neo-opensuse-i3-session' + LineEnding;

function ShouldInstallXinitrc(Mode: TInstallXinitrcMode; const DM: TDisplayManagerInfo; Wayland: Boolean): Boolean;
begin
  if Wayland then
  begin
    Result := False;
    Exit;
  end;
  case Mode of
    xmAlways: Result := True;
    xmNever: Result := False;
  else
    Result := not DM.Running;
  end;
end;

function InstallXinitrcForUser(const U: TUserInfo; const BackupRoot: string; DryRun: Boolean; Log: TLogger): Boolean;
var
  R: TFileOpResult;
begin
  Result := WriteTextAtomic(XinitrcContent, U.Home + DirectorySeparator + '.xinitrc',
    BackupRoot, U.Name, U.UID, U.GID, &755, DryRun, Log, R);
end;

end.
