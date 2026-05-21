unit backup_manager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, constants;

function SystemBackupRootForStamp(const Stamp: string): string;
function UserBackupRootForStamp(const Home, Stamp: string): string;

implementation

function SystemBackupRootForStamp(const Stamp: string): string;
begin
  Result := '/var/lib/' + AppName + '/backups/' + Stamp;
end;

function UserBackupRootForStamp(const Home, Stamp: string): string;
begin
  Result := Home + DirectorySeparator + '.local/share/' + AppName + '/backups/' + Stamp;
end;

end.
