unit session_manager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, logger;

function InstallSessionFiles(const BackupRoot: string; DryRun: Boolean; Log: TLogger; Wayland: Boolean): Boolean;

implementation

uses
  file_ops;

const
  XorgSessionLauncher =
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

  XorgDesktopEntry =
    '[Desktop Entry]' + LineEnding +
    'Name=Neo openSUSE i3' + LineEnding +
    'Comment=Polished i3 session configured by neo-opensuse-i3' + LineEnding +
    'Exec=/usr/local/bin/neo-opensuse-i3-session' + LineEnding +
    'Type=Application' + LineEnding +
    'DesktopNames=i3' + LineEnding;

  WaylandSessionLauncher =
    '#!/bin/sh' + LineEnding +
    'export XDG_CURRENT_DESKTOP=sway' + LineEnding +
    'export XDG_SESSION_DESKTOP=sway' + LineEnding +
    'export DESKTOP_SESSION=neo-opensuse-sway' + LineEnding +
    'export XDG_SESSION_TYPE=wayland' + LineEnding +
    'if command -v systemctl >/dev/null 2>&1; then' + LineEnding +
    '  systemctl --user import-environment XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP DESKTOP_SESSION XDG_SESSION_TYPE DBUS_SESSION_BUS_ADDRESS >/dev/null 2>&1 || true' + LineEnding +
    'fi' + LineEnding +
    'if [ -z "${DBUS_SESSION_BUS_ADDRESS:-}" ] && command -v dbus-run-session >/dev/null 2>&1; then' + LineEnding +
    '  exec dbus-run-session -- sway' + LineEnding +
    'fi' + LineEnding +
    'exec sway' + LineEnding;

  WaylandDesktopEntry =
    '[Desktop Entry]' + LineEnding +
    'Name=Neo openSUSE Sway' + LineEnding +
    'Comment=Polished Sway session configured by neo-opensuse-i3' + LineEnding +
    'Exec=/usr/local/bin/neo-opensuse-sway-session' + LineEnding +
    'Type=Application' + LineEnding +
    'DesktopNames=sway' + LineEnding;

function InstallSessionFiles(const BackupRoot: string; DryRun: Boolean; Log: TLogger; Wayland: Boolean): Boolean;
var
  R: TFileOpResult;
begin
  Result := True;
  if Wayland then
  begin
    Result := WriteTextAtomic(WaylandSessionLauncher, '/usr/local/bin/neo-opensuse-sway-session',
      BackupRoot, 'root', 0, 0, &755, DryRun, Log, R) and Result;
    Result := WriteTextAtomic(WaylandDesktopEntry, '/usr/share/wayland-sessions/neo-opensuse-sway.desktop',
      BackupRoot, 'root', 0, 0, &644, DryRun, Log, R) and Result;
  end
  else
  begin
    Result := WriteTextAtomic(XorgSessionLauncher, '/usr/local/bin/neo-opensuse-i3-session',
      BackupRoot, 'root', 0, 0, &755, DryRun, Log, R) and Result;
    Result := WriteTextAtomic(XorgDesktopEntry, '/usr/share/xsessions/neo-opensuse-i3.desktop',
      BackupRoot, 'root', 0, 0, &644, DryRun, Log, R) and Result;
  end;
end;

end.
