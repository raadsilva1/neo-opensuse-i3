program neo_opensuse_i3;

{$mode objfpc}{$H+}

uses
  SysUtils, Classes, BaseUnix,
  constants, models, app_context, cli_options, logger, glib_runtime, asset_locator,
  asset_validator, os_detect, privilege, lockfile, user_detect,
  display_manager, gpu_detect, zypper, package_resolver, session_manager,
  asset_installer, xinitrc_manager, validator, rollback_manager, tui,
  json_writer, checksum;

procedure FailAndHalt(Code: Integer; const Msg: string; Log: TLogger);
begin
  if Msg <> '' then
  begin
    Writeln(ErrOutput, Msg);
    if Assigned(Log) then Log.Error(Msg);
  end;
  Halt(Code);
end;

function JsonBool(Value: Boolean): string;
begin
  if Value then Result := 'true' else Result := 'false';
end;

function JsonComma(Condition: Boolean): string;
begin
  if Condition then Result := ',' else Result := '';
end;

procedure WriteUserSummaries(const Users: TUserArray; const Ctx: TAppContext);
var
  I: Integer;
  Dir, Path: string;
  F: TextFile;
begin
  if Ctx.Options.DryRun then Exit;
  for I := 0 to High(Users) do
  begin
    Dir := Users[I].Home + '/.local/share/neo-opensuse-i3';
    ForceDirectories(Dir);
    Path := Dir + '/install-summary.json';
    AssignFile(F, Path);
    Rewrite(F);
    Writeln(F, '{');
    Writeln(F, JsonPair('app', AppName));
    Writeln(F, JsonPair('version', AppVersion));
    Writeln(F, JsonPair('user', Users[I].Name));
    Writeln(F, JsonPair('assets_dir', Ctx.AssetsDir));
    Writeln(F, JsonPair('theme', Ctx.Options.Theme));
    Writeln(F, JsonPair('wayland', JsonBool(Ctx.Options.Wayland)));
    Writeln(F, JsonPair('log_file', Ctx.Log.TextPath, True));
    Writeln(F, '}');
    CloseFile(F);
    fpChown(PChar(Path), Users[I].UID, Users[I].GID);
    fpChmod(PChar(Path), &644);
  end;
end;

procedure PrintAssetFailure(const AssetsDir: string; const Missing: TStringArray);
var
  I: Integer;
begin
  Writeln(ErrOutput, 'Required assets are missing.');
  Writeln(ErrOutput, 'Resolved assets path: ', AssetsDir);
  for I := 0 to High(Missing) do
    Writeln(ErrOutput, '  - ', Missing[I]);
end;

procedure AddLine(L: TStringList; const S: string);
begin
  L.Add(S);
end;

function BuildStructuredReport(const Ctx: TAppContext; Success: Boolean; ExitCode: Integer; InstallXinitrc: Boolean): string;
var
  L: TStringList;
  I: Integer;
  P: string;
  AssetFilesXorg: array[0..6] of string = (
    'i3/config',
    'bin/lbemenu',
    'kitty/kitty.conf',
    'kitty/themes/Emerald-Night.conf',
    'kitty/themes/Forest-Moss.conf',
    'kitty/themes/Sage-Light.conf',
    'wallpapers/suse.png');
  AssetFilesWayland: array[0..12] of string = (
    'sway/config',
    'bin/lfuzzel',
    'sway/themes/Emerald-Night.conf',
    'sway/themes/Forest-Moss.conf',
    'sway/themes/Sage-Light.conf',
    'fuzzel/themes/Emerald-Night.ini',
    'fuzzel/themes/Forest-Moss.ini',
    'fuzzel/themes/Sage-Light.ini',
    'kitty/kitty.conf',
    'kitty/themes/Emerald-Night.conf',
    'kitty/themes/Forest-Moss.conf',
    'kitty/themes/Sage-Light.conf',
    'wallpapers/suse.png');
begin
  L := TStringList.Create;
  try
    AddLine(L, '{');
    AddLine(L, '  "app": "' + JsonEscape(AppName) + '",');
    AddLine(L, '  "version": "' + JsonEscape(AppVersion) + '",');
    AddLine(L, '  "success": ' + JsonBool(Success) + ',');
    AddLine(L, '  "exit_code": ' + IntToStr(ExitCode) + ',');
    AddLine(L, '  "dry_run": ' + JsonBool(Ctx.Options.DryRun) + ',');
    AddLine(L, '  "assets_dir": "' + JsonEscape(Ctx.AssetsDir) + '",');
    AddLine(L, '  "asset_source": "' + JsonEscape(Ctx.AssetSource) + '",');
    AddLine(L, '  "selected_theme": "' + JsonEscape(Ctx.Options.Theme) + '",');
    AddLine(L, '  "wayland": ' + JsonBool(Ctx.Options.Wayland) + ',');
    AddLine(L, '  "install_xinitrc": ' + JsonBool(InstallXinitrc) + ',');
    AddLine(L, '  "log_file": "' + JsonEscape(Ctx.Log.TextPath) + '",');
    AddLine(L, '  "os": {');
    AddLine(L, '    "id": "' + JsonEscape(Ctx.OSInfo.ID) + '",');
    AddLine(L, '    "pretty_name": "' + JsonEscape(Ctx.OSInfo.PrettyName) + '",');
    AddLine(L, '    "version_id": "' + JsonEscape(Ctx.OSInfo.VersionID) + '",');
    AddLine(L, '    "is_tumbleweed": ' + JsonBool(Ctx.OSInfo.IsTumbleweed));
    AddLine(L, '  },');
    AddLine(L, '  "glib": { "available": ' + JsonBool(Ctx.GLib.Available) + ', "detail": "' + JsonEscape(Ctx.GLib.Detail) + '" },');
    AddLine(L, '  "display_manager": { "name": "' + JsonEscape(Ctx.DisplayManager.Name) + '", "running": ' + JsonBool(Ctx.DisplayManager.Running) + ', "detail": "' + JsonEscape(Ctx.DisplayManager.Detail) + '" },');
    AddLine(L, '  "gpu": { "summary": "' + JsonEscape(Ctx.GPU.Summary) + '", "packages": "' + JsonEscape(JoinStrings(Ctx.GPU.Packages, ', ')) + '", "warnings": "' + JsonEscape(JoinStrings(Ctx.GPU.Warnings, '; ')) + '" },');
    AddLine(L, '  "asset_checksums": [');
    if Ctx.Options.Wayland then
    begin
      for I := Low(AssetFilesWayland) to High(AssetFilesWayland) do
      begin
        P := Ctx.AssetsDir + DirectorySeparator + AssetFilesWayland[I];
        AddLine(L, '    { "path": "' + JsonEscape(AssetFilesWayland[I]) + '", "sha256": "' + JsonEscape(SHA256File(P)) + '" }' + JsonComma(I < High(AssetFilesWayland)));
      end;
    end
    else
    begin
      for I := Low(AssetFilesXorg) to High(AssetFilesXorg) do
      begin
        P := Ctx.AssetsDir + DirectorySeparator + AssetFilesXorg[I];
        AddLine(L, '    { "path": "' + JsonEscape(AssetFilesXorg[I]) + '", "sha256": "' + JsonEscape(SHA256File(P)) + '" }' + JsonComma(I < High(AssetFilesXorg)));
      end;
    end;
    AddLine(L, '  ],');
    AddLine(L, '  "target_users": [');
    for I := 0 to High(Ctx.Users) do
      AddLine(L, '    { "name": "' + JsonEscape(Ctx.Users[I].Name) + '", "uid": ' + IntToStr(Ctx.Users[I].UID) + ', "gid": ' + IntToStr(Ctx.Users[I].GID) + ', "home": "' + JsonEscape(Ctx.Users[I].Home) + '" }' + JsonComma(I < High(Ctx.Users)));
    AddLine(L, '  ],');
    AddLine(L, '  "package_decisions": [');
    for I := 0 to High(Ctx.PackageDecisions) do
      AddLine(L, '    { "name": "' + JsonEscape(Ctx.PackageDecisions[I].Name) + '", "group": "' + JsonEscape(Ctx.PackageDecisions[I].GroupName) + '", "installed": ' + JsonBool(Ctx.PackageDecisions[I].Installed) + ', "candidate": ' + JsonBool(Ctx.PackageDecisions[I].Candidate) + ', "required": ' + JsonBool(Ctx.PackageDecisions[I].Required) + ', "selected": ' + JsonBool(Ctx.PackageDecisions[I].Selected) + ', "reason": "' + JsonEscape(Ctx.PackageDecisions[I].Reason) + '" }' + JsonComma(I < High(Ctx.PackageDecisions)));
    AddLine(L, '  ],');
    AddLine(L, '  "packages_to_install": "' + JsonEscape(JoinStrings(Ctx.PackagesToInstall, ', ')) + '",');
    AddLine(L, '  "missing_required_packages": "' + JsonEscape(JoinStrings(Ctx.MissingRequiredPackages, ', ')) + '"');
    AddLine(L, '}');
    Result := L.Text;
  finally
    L.Free;
  end;
end;

var
  Ctx: TAppContext;
  ParseError, LogWarning, Message, AssetWarning: string;
  MissingAssets: TStringArray;
  Log: TLogger;
  Lock: TAppLock;
  Success, InstallXinitrc: Boolean;
  ExitCode: Integer;
begin
  Log := TLogger.Create;
  Lock := TAppLock.Create;
  try
    if not ParseCLI(Ctx.Options, ParseError) then
    begin
      Writeln(ErrOutput, ParseError);
      PrintHelp;
      Halt(ExitInvalidCLI);
    end;
    if GetEnvironmentVariable('NO_COLOR') <> '' then
      Ctx.Options.Plain := True;
    if Ctx.Options.ShowHelp then
    begin
      PrintHelp;
      Halt(ExitSuccess);
    end;
    if Ctx.Options.ShowVersion then
    begin
      Writeln(AppName, ' ', AppVersion);
      Halt(ExitSuccess);
    end;

    if not Log.Open(Ctx.Options.LogFile, Ctx.Options.DryRun, LogWarning) then
      Halt(ExitGenericFailure);
    Ctx.Log := Log;
    if LogWarning <> '' then
    begin
      Writeln(LogWarning);
      Log.Warn(LogWarning);
    end;

    if Ctx.Options.ListBackups then
    begin
      if ListBackups(Log) then Halt(ExitSuccess) else Halt(ExitRollbackFailure);
    end;

    if Ctx.Options.Rollback then
    begin
      if not IsRoot then FailAndHalt(ExitMissingPrivileges, '--rollback requires root privileges', Log);
      if RollbackLatest(Log) then Halt(ExitSuccess) else Halt(ExitRollbackFailure);
    end;

    Ctx.BackupStamp := RunStamp;
    Ctx.SystemBackupRoot := '/var/lib/' + AppName + '/backups/' + Ctx.BackupStamp;
    Ctx.GLib := CheckGLib;
    if Ctx.GLib.Available then Log.Info(Ctx.GLib.Detail) else Log.Warn(Ctx.GLib.Detail);

    if not LocateAssets(Ctx.Options, Ctx.AssetsDir, Ctx.AssetSource) then
      FailAndHalt(ExitMissingAssets, 'assets directory was not found; checked --assets-dir, NEO_OPENSUSE_I3_ASSETS, executable ./assets, and cwd ./assets', Log);
    if not ValidateAssets(Ctx.AssetsDir, Ctx.Options.Theme, Ctx.Options.Wayland, Log, MissingAssets, AssetWarning) then
    begin
      PrintAssetFailure(Ctx.AssetsDir, MissingAssets);
      Halt(ExitMissingAssets);
    end;
    if AssetWarning <> '' then Writeln(AssetWarning);

    Ctx.OSInfo := ReadOSInfo;
    if not ValidateOS(Ctx.OSInfo, Ctx.Options.Force, Log, Message) then
      FailAndHalt(ExitInvalidOS, Message, Log);

    if (not Ctx.Options.DryRun) and (not IsRoot) then
      FailAndHalt(ExitMissingPrivileges, 'installation requires root privileges; re-run with sudo or use --dry-run', Log);
    if not Lock.Acquire(Ctx.Options.DryRun, Message) then
      FailAndHalt(ExitLockHeld, Message, Log);

    if not ZypperAvailable then
      FailAndHalt(ExitPackageFailure, 'zypper was not found in PATH', Log);
    if not RepoAvailable(Log) then
      FailAndHalt(ExitPackageFailure, 'zypper repositories are not available', Log);

    Ctx.Users := DetectTargetUsers(Ctx.Options, Log);
    if Length(Ctx.Users) = 0 then
      Log.Warn('no sudo-capable human target users were detected');
    Ctx.DisplayManager := DetectDisplayManager(Log);
    Ctx.GPU := DetectGPU(Ctx.Options, Log);
    if not ResolvePackages(Ctx.Options, Ctx.GPU, Log, Ctx.PackageDecisions, Ctx.MissingRequiredPackages, Ctx.PackagesToInstall) then
      FailAndHalt(ExitPackageFailure, 'missing required package candidates: ' + JoinStrings(Ctx.MissingRequiredPackages, ', '), Log);

    ShowWelcome(Ctx);
    ShowPreflight(Ctx);
    if not ConfirmInstall(Ctx) then
      FailAndHalt(ExitGenericFailure, 'installation cancelled by user', Log);

    Success := True;
    ExitCode := ExitSuccess;
    InstallXinitrc := ShouldInstallXinitrc(Ctx.Options.InstallXinitrc, Ctx.DisplayManager, Ctx.Options.Wayland);

    if not InstallPackages(Ctx.PackagesToInstall, Ctx.Options.DryRun, Log) then
    begin
      Success := False; ExitCode := ExitPackageFailure;
    end;
    if Success and (not InstallSessionFiles(Ctx.SystemBackupRoot, Ctx.Options.DryRun, Log, Ctx.Options.Wayland)) then
    begin
      Success := False; ExitCode := ExitFileFailure;
    end;
    if Success and (not InstallSystemAssets(Ctx.AssetsDir, Ctx.SystemBackupRoot, Ctx.Options.Wayland, Ctx.Options.DryRun, Log)) then
      if Ctx.Options.Wayland then
        Log.Warn('continuing after system lfuzzel install warning because per-user fallback is installed')
      else
        Log.Warn('continuing after system lbemenu install warning because per-user fallback is installed');
    if Success and (not InstallAssetsForUsers(Ctx.AssetsDir, Ctx.BackupStamp, Ctx.Users, InstallXinitrc, Ctx.Options.Wayland, Ctx.Options.Theme, Ctx.Options.DryRun, Log)) then
    begin
      Success := False; ExitCode := ExitFileFailure;
    end;
    if Success and (not ValidateInstall(Ctx.Users, Ctx.AssetsDir, Ctx.Options.Theme, InstallXinitrc, Ctx.Options.Wayland, Ctx.Options.DryRun, Log)) then
    begin
      Success := False; ExitCode := ExitValidationFailure;
    end;
    if Success then
      WriteUserSummaries(Ctx.Users, Ctx);
    ShowSummary(Ctx, Success, ExitCode);
    Log.WriteStructuredJson(BuildStructuredReport(Ctx, Success, ExitCode, InstallXinitrc));
    Halt(ExitCode);
  finally
    Lock.Free;
    Log.Free;
  end;
end.
