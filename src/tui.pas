unit tui;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, app_context;

procedure ShowWelcome(const Ctx: TAppContext);
procedure ShowPreflight(const Ctx: TAppContext);
function ConfirmInstall(const Ctx: TAppContext): Boolean;
procedure ShowSummary(const Ctx: TAppContext; Success: Boolean; ExitCode: Integer);

implementation

uses
  constants, models, tui_theme, tui_widgets;

procedure Header(const Title: string; Plain: Boolean);
begin
  if Plain then
  begin
    Writeln;
    Writeln('== ', Title, ' ==');
  end
  else
  begin
    Writeln;
    Writeln(CBold, CBrightGreen, ' neo openSUSE i3 ', CReset, CMuted, Title, CReset);
    Writeln(CGreen, StringOfChar('-', 72), CReset);
  end;
end;

procedure ShowWelcome(const Ctx: TAppContext);
var
  ModeText: string;
begin
  Header('installer', Ctx.Options.Plain);
  if Ctx.Options.DryRun then ModeText := 'dry-run' else ModeText := 'install';
  Writeln('Version: ', AppVersion);
  Writeln('Mode: ', ModeText);
  Writeln('Theme: ', Ctx.Options.Theme);
end;

procedure ShowPreflight(const Ctx: TAppContext);
var
  I: Integer;
begin
  Header('preflight', Ctx.Options.Plain);
  PrintStatus('GLib integration', 'success', Ctx.GLib.Detail, Ctx.Options.Plain);
  PrintStatus('Assets validation', 'success', Ctx.AssetsDir + ' (' + Ctx.AssetSource + ')', Ctx.Options.Plain);
  PrintStatus('OS validation', 'success', Ctx.OSInfo.PrettyName, Ctx.Options.Plain);
  PrintStatus('Target users', 'success', IntToStr(Length(Ctx.Users)) + ' selected', Ctx.Options.Plain);
  for I := 0 to High(Ctx.Users) do
    Writeln('  - ', Ctx.Users[I].Name, ' ', Ctx.Users[I].Home);
  PrintStatus('GPU/platform', 'success', Ctx.GPU.Summary, Ctx.Options.Plain);
  PrintStatus('Display/session manager', 'success', Ctx.DisplayManager.Name + ', running=' + BoolText(Ctx.DisplayManager.Running), Ctx.Options.Plain);
  PrintStatus('Package plan', 'success', IntToStr(Length(Ctx.PackagesToInstall)) + ' missing packages selected', Ctx.Options.Plain);
  if Length(Ctx.PackagesToInstall) > 0 then
    Writeln('  ', JoinStrings(Ctx.PackagesToInstall, ', '));
end;

procedure ShowInteractiveScreen(const Ctx: TAppContext; Index: Integer);
begin
  case Index of
    0:
      begin
        Header('welcome', Ctx.Options.Plain);
        Writeln('Installer: ', AppName, ' ', AppVersion);
        Writeln('Mode: install');
      end;
    1:
      begin
        Header('preflight', Ctx.Options.Plain);
        PrintStatus('GLib integration', 'success', Ctx.GLib.Detail, Ctx.Options.Plain);
        PrintStatus('Lock/privileges', 'success', 'root privileges and installer lock are ready', Ctx.Options.Plain);
      end;
    2:
      begin
        Header('assets', Ctx.Options.Plain);
        PrintStatus('Runtime assets', 'success', Ctx.AssetsDir + ' (' + Ctx.AssetSource + ')', Ctx.Options.Plain);
        Writeln('Theme: ', Ctx.Options.Theme);
      end;
    3:
      begin
        Header('os', Ctx.Options.Plain);
        PrintStatus('openSUSE validation', 'success', Ctx.OSInfo.PrettyName, Ctx.Options.Plain);
      end;
    4:
      begin
        Header('users', Ctx.Options.Plain);
        PrintStatus('Target users', 'success', IntToStr(Length(Ctx.Users)) + ' selected', Ctx.Options.Plain);
      end;
    5:
      begin
        Header('packages', Ctx.Options.Plain);
        PrintStatus('zypper plan', 'success', IntToStr(Length(Ctx.PackagesToInstall)) + ' packages to install', Ctx.Options.Plain);
        if Length(Ctx.PackagesToInstall) > 0 then Writeln(JoinStrings(Ctx.PackagesToInstall, ', '));
      end;
    6:
      begin
        Header('gpu', Ctx.Options.Plain);
        PrintStatus('Detected platform', 'success', Ctx.GPU.Summary, Ctx.Options.Plain);
        if Length(Ctx.GPU.Warnings) > 0 then Writeln(JoinStrings(Ctx.GPU.Warnings, '; '));
      end;
    7:
      begin
        Header('session', Ctx.Options.Plain);
        PrintStatus('Display manager', 'success', Ctx.DisplayManager.Name + ', running=' + BoolText(Ctx.DisplayManager.Running), Ctx.Options.Plain);
        Writeln('X session entry: /usr/share/xsessions/neo-opensuse-i3.desktop');
      end;
    8:
      begin
        Header('progress', Ctx.Options.Plain);
        PrintStatus('Package install', 'pending', 'zypper install only missing selected packages', Ctx.Options.Plain);
        PrintStatus('File install', 'pending', 'session files and per-user configuration with backups', Ctx.Options.Plain);
        PrintStatus('Validation', 'pending', 'i3, Kitty, session launcher, lbemenu, ownership, and logs', Ctx.Options.Plain);
      end;
  else
    begin
      Header('summary', Ctx.Options.Plain);
      Writeln('Log: ', Ctx.Log.TextPath);
      Writeln('JSON log: ', Ctx.Log.JsonPath);
    end;
  end;
end;

function NavigateConfirmationScreens(const Ctx: TAppContext): Boolean;
var
  Index: Integer;
  S: string;
begin
  Result := False;
  Index := 0;
  repeat
    ShowInteractiveScreen(Ctx, Index);
    Writeln;
    Write('[n]ext [p]revious [c]ontinue [q]uit > ');
    ReadLn(S);
    S := LowerCase(Trim(S));
    if (S = 'n') or (S = '') then
    begin
      if Index < 9 then Inc(Index);
    end
    else if S = 'p' then
    begin
      if Index > 0 then Dec(Index);
    end
    else if (S = 'c') or (S = 'continue') then
      Exit(True)
    else if (S = 'q') or (S = 'quit') then
      Exit(False);
  until False;
end;

function ConfirmInstall(const Ctx: TAppContext): Boolean;
var
  S: string;
begin
  if Ctx.Options.DryRun or Ctx.Options.Unattended then Exit(True);
  if not NavigateConfirmationScreens(Ctx) then Exit(False);
  Header('confirmation', Ctx.Options.Plain);
  Writeln('This will install packages with zypper and write system/user desktop configuration.');
  Write('Continue? [y/N] ');
  ReadLn(S);
  Result := (LowerCase(Trim(S)) = 'y') or (LowerCase(Trim(S)) = 'yes');
end;

procedure ShowSummary(const Ctx: TAppContext; Success: Boolean; ExitCode: Integer);
begin
  Header('summary', Ctx.Options.Plain);
  if Success then
    PrintStatus('Installer result', 'success', 'completed with exit code 0', Ctx.Options.Plain)
  else
    PrintStatus('Installer result', 'failed', 'exit code ' + IntToStr(ExitCode), Ctx.Options.Plain);
  Writeln('Log: ', Ctx.Log.TextPath);
  Writeln('JSON log: ', Ctx.Log.JsonPath);
  if Ctx.Options.DryRun then
    Writeln('Dry-run made no system changes.');
end;

end.
