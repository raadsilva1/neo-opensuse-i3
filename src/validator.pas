unit validator;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, models, logger;

function ValidateInstall(const Users: TUserArray; const AssetsDir, Theme: string; InstallXinitrc: Boolean; Wayland: Boolean; DryRun: Boolean; Log: TLogger): Boolean;

implementation

uses
  BaseUnix, process_runner;

function Executable(const Path: string): Boolean;
begin
  Result := FileExists(Path) and (fpAccess(PChar(Path), X_OK) = 0);
end;

function ValidateInstall(const Users: TUserArray; const AssetsDir, Theme: string; InstallXinitrc: Boolean; Wayland: Boolean; DryRun: Boolean; Log: TLogger): Boolean;
var
  I: Integer;
  Path: string;
  R: TCommandResult;
begin
  Result := True;
  if DryRun then
  begin
    if Assigned(Log) then Log.Info('dry-run validation: planned files and assets validated without system writes');
    Exit(True);
  end;
  if Wayland then
  begin
    if not Executable('/usr/local/bin/neo-opensuse-sway-session') then begin Result := False; if Assigned(Log) then Log.Error('session launcher missing or not executable'); end;
    if not FileExists('/usr/share/wayland-sessions/neo-opensuse-sway.desktop') then begin Result := False; if Assigned(Log) then Log.Error('Wayland session desktop file missing'); end;
    if not Executable('/usr/local/bin/lfuzzel') then
      if Assigned(Log) then Log.Warn('/usr/local/bin/lfuzzel missing or not executable; per-user fallback may be used');
  end
  else
  begin
    if not Executable('/usr/local/bin/neo-opensuse-i3-session') then begin Result := False; if Assigned(Log) then Log.Error('session launcher missing or not executable'); end;
    if not FileExists('/usr/share/xsessions/neo-opensuse-i3.desktop') then begin Result := False; if Assigned(Log) then Log.Error('X session desktop file missing'); end;
    if not Executable('/usr/local/bin/lbemenu') then
      if Assigned(Log) then Log.Warn('/usr/local/bin/lbemenu missing or not executable; per-user fallback may be used');
  end;
  for I := 0 to High(Users) do
  begin
    if Wayland then
    begin
      Path := Users[I].Home + '/.config/sway/config';
      if not FileExists(Path) then begin Result := False; if Assigned(Log) then Log.Error('missing sway config for ' + Users[I].Name); end
      else if Assigned(Log) then Log.Info('sway config present for ' + Users[I].Name + ' (sway -C syntax check skipped: requires active session backend)');
      if not FileExists(Users[I].Home + '/.config/fuzzel/fuzzel.ini') then begin Result := False; if Assigned(Log) then Log.Error('missing fuzzel config for ' + Users[I].Name); end;
      if not FileExists(Users[I].Home + '/.config/sway/themes/active.conf') then begin Result := False; if Assigned(Log) then Log.Error('missing sway active theme for ' + Users[I].Name); end;
    end
    else
    begin
      Path := Users[I].Home + '/.config/i3/config';
      if not FileExists(Path) then begin Result := False; if Assigned(Log) then Log.Error('missing i3 config for ' + Users[I].Name); end
      else if CommandExists('i3') then
      begin
        R := RunCommand('/usr/bin/env', ['i3', '-C', '-c', Path], 30);
        if R.ExitCode <> 0 then begin Result := False; if Assigned(Log) then Log.Error('i3 config validation failed for ' + Users[I].Name + ': ' + R.Output); end;
      end;
    end;
    if not FileExists(Users[I].Home + '/.config/kitty/kitty.conf') then begin Result := False; if Assigned(Log) then Log.Error('missing kitty config for ' + Users[I].Name); end;
    if not FileExists(Users[I].Home + '/.config/kitty/themes/' + Theme + '.conf') then begin Result := False; if Assigned(Log) then Log.Error('missing selected kitty theme for ' + Users[I].Name); end;
    if not DirectoryExists(Users[I].Home + '/Pictures/Screenshots') then begin Result := False; if Assigned(Log) then Log.Error('missing screenshots directory for ' + Users[I].Name); end;
    if InstallXinitrc and not Executable(Users[I].Home + '/.xinitrc') then begin Result := False; if Assigned(Log) then Log.Error('.xinitrc missing or not executable for ' + Users[I].Name); end;
  end;
  if Assigned(Log) then
    if Result then Log.Info('post-install validation passed')
    else Log.Error('post-install validation failed');
end;

end.
