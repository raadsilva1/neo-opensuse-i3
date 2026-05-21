unit constants;

{$mode objfpc}{$H+}

interface

const
  AppName = 'neo-opensuse-i3';
  AppVersion = '1.0.0';
  DefaultTheme = 'Forest-Moss';

  ExitSuccess = 0;
  ExitGenericFailure = 1;
  ExitInvalidOS = 2;
  ExitMissingPrivileges = 3;
  ExitMissingAssets = 4;
  ExitPackageFailure = 5;
  ExitFileFailure = 6;
  ExitValidationFailure = 7;
  ExitRollbackFailure = 8;
  ExitLockHeld = 9;
  ExitInvalidCLI = 10;

implementation

end.
