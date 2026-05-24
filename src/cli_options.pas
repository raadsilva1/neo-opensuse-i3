unit cli_options;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, constants, models;

function ParseCLI(out Options: TCLIOptions; out ErrorMessage: string): Boolean;
procedure PrintHelp;

implementation

procedure InitDefaults(var Options: TCLIOptions);
begin
  FillChar(Options, SizeOf(Options), 0);
  Options.AllSudoUsers := True;
  Options.Theme := DefaultTheme;
  Options.InstallXinitrc := xmIfNoDisplayManager;
  Options.NvidiaPolicy := npNouveau;
end;

function NeedValue(const I: Integer; out ErrorMessage: string): Boolean;
begin
  Result := I < ParamCount;
  if not Result then
    ErrorMessage := 'missing value for ' + ParamStr(I);
end;

function ParseCLI(out Options: TCLIOptions; out ErrorMessage: string): Boolean;
var
  I: Integer;
  Arg, Value: string;
begin
  InitDefaults(Options);
  Result := True;
  ErrorMessage := '';
  I := 1;
  while I <= ParamCount do
  begin
    Arg := ParamStr(I);
    if Arg = '--help' then Options.ShowHelp := True
    else if Arg = '--version' then Options.ShowVersion := True
    else if Arg = '--dry-run' then Options.DryRun := True
    else if Arg = '--plain' then Options.Plain := True
    else if Arg = '--unattended' then Options.Unattended := True
    else if Arg = '--force' then Options.Force := True
    else if Arg = '--rollback' then Options.Rollback := True
    else if Arg = '--list-backups' then Options.ListBackups := True
    else if Arg = '--wayland' then Options.Wayland := True
    else if Arg = '--all-sudo-users' then Options.AllSudoUsers := True
    else if Arg = '--assets-dir' then
    begin
      if not NeedValue(I, ErrorMessage) then Exit(False);
      Inc(I); Options.AssetsDir := ParamStr(I);
    end
    else if Arg = '--user' then
    begin
      if not NeedValue(I, ErrorMessage) then Exit(False);
      Inc(I); AddString(Options.Users, ParamStr(I)); Options.AllSudoUsers := False;
    end
    else if Arg = '--exclude-user' then
    begin
      if not NeedValue(I, ErrorMessage) then Exit(False);
      Inc(I); AddString(Options.ExcludedUsers, ParamStr(I));
    end
    else if Arg = '--theme' then
    begin
      if not NeedValue(I, ErrorMessage) then Exit(False);
      Inc(I); Options.Theme := ParamStr(I);
    end
    else if Arg = '--install-xinitrc' then
    begin
      if not NeedValue(I, ErrorMessage) then Exit(False);
      Inc(I); Value := ParamStr(I);
      if Value = 'always' then Options.InstallXinitrc := xmAlways
      else if Value = 'if-no-display-manager' then Options.InstallXinitrc := xmIfNoDisplayManager
      else if Value = 'never' then Options.InstallXinitrc := xmNever
      else begin ErrorMessage := 'invalid --install-xinitrc value: ' + Value; Exit(False); end;
    end
    else if Arg = '--nvidia-policy' then
    begin
      if not NeedValue(I, ErrorMessage) then Exit(False);
      Inc(I); Value := ParamStr(I);
      if Value = 'nouveau' then Options.NvidiaPolicy := npNouveau
      else if Value = 'proprietary-prompt' then Options.NvidiaPolicy := npProprietaryPrompt
      else if Value = 'skip' then Options.NvidiaPolicy := npSkip
      else begin ErrorMessage := 'invalid --nvidia-policy value: ' + Value; Exit(False); end;
    end
    else if Arg = '--log-file' then
    begin
      if not NeedValue(I, ErrorMessage) then Exit(False);
      Inc(I); Options.LogFile := ParamStr(I);
    end
    else
    begin
      ErrorMessage := 'unknown option: ' + Arg;
      Exit(False);
    end;
    Inc(I);
  end;
end;

procedure PrintHelp;
begin
  Writeln(AppName, ' ', AppVersion);
  Writeln('Usage: ', AppName, ' [options]');
  Writeln;
  Writeln('Options:');
  Writeln('  --help');
  Writeln('  --version');
  Writeln('  --dry-run');
  Writeln('  --plain');
  Writeln('  --unattended');
  Writeln('  --force');
  Writeln('  --assets-dir PATH');
  Writeln('  --rollback');
  Writeln('  --list-backups');
  Writeln('  --wayland');
  Writeln('  --all-sudo-users');
  Writeln('  --user USER');
  Writeln('  --exclude-user USER');
  Writeln('  --theme THEME');
  Writeln('  --install-xinitrc always|if-no-display-manager|never');
  Writeln('  --nvidia-policy nouveau|proprietary-prompt|skip');
  Writeln('  --log-file PATH');
end;

end.
