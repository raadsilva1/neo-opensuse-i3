unit session_manager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, logger;

function InstallSessionFiles(const BackupRoot: string; DryRun: Boolean; Log: TLogger): Boolean;

implementation

uses
  file_ops;

const
  SessionLauncher =
    '#!/bin/sh' + LineEnding +
    'export XDG_CURRENT_DESKTOP=i3' + LineEnding +
    'export XDG_SESSION_DESKTOP=i3' + LineEnding +
    'export DESKTOP_SESSION=neo-opensuse-i3' + LineEnding +
    'if command -v systemctl >/dev/null 2>&1; then' + LineEnding +
    '  systemctl --user import-environment DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION DBUS_SESSION_BUS_ADDRESS >/dev/null 2>&1 || true' + LineEnding +
    'fi' + LineEnding +
    'if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null 2>&1; then' + LineEnding +
    '  exec dbus-run-session -- i3' + LineEnding +
    'fi' + LineEnding +
    'exec i3' + LineEnding;

  DesktopEntry =
    '[Desktop Entry]' + LineEnding +
    'Name=Neo openSUSE i3' + LineEnding +
    'Comment=Polished i3 session configured by neo-opensuse-i3' + LineEnding +
    'Exec=/usr/local/bin/neo-opensuse-i3-session' + LineEnding +
    'Type=Application' + LineEnding +
    'DesktopNames=i3' + LineEnding;

function InstallSessionFiles(const BackupRoot: string; DryRun: Boolean; Log: TLogger): Boolean;
var
  R: TFileOpResult;
begin
  Result := True;
  Result := WriteTextAtomic(SessionLauncher, '/usr/local/bin/neo-opensuse-i3-session',
    BackupRoot, 'root', 0, 0, &755, DryRun, Log, R) and Result;
  Result := WriteTextAtomic(DesktopEntry, '/usr/share/xsessions/neo-opensuse-i3.desktop',
    BackupRoot, 'root', 0, 0, &644, DryRun, Log, R) and Result;
end;

end.
