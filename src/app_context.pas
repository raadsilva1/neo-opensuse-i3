unit app_context;

{$mode objfpc}{$H+}

interface

uses
  constants, models, logger, os_detect, display_manager, gpu_detect, glib_runtime;

type
  TAppContext = record
    Options: TCLIOptions;
    AssetsDir: string;
    AssetSource: string;
    BackupStamp: string;
    SystemBackupRoot: string;
    OSInfo: TOSInfo;
    GLib: TGLibStatus;
    DisplayManager: TDisplayManagerInfo;
    GPU: TGPUInfo;
    Users: TUserArray;
    PackageDecisions: TPackageDecisionArray;
    MissingRequiredPackages: TStringArray;
    PackagesToInstall: TStringArray;
    Log: TLogger;
  end;

implementation

end.
