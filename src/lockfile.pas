unit lockfile;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  TAppLock = class
  private
    FPath: string;
    FHeld: Boolean;
  public
    function Acquire(const DryRun: Boolean; out Message: string): Boolean;
    procedure Release;
    destructor Destroy; override;
  end;

implementation

function TAppLock.Acquire(const DryRun: Boolean; out Message: string): Boolean;
var
  F: TextFile;
begin
  Message := '';
  if DryRun then
  begin
    FHeld := False;
    Exit(True);
  end;
  FPath := '/run/lock/neo-opensuse-i3.lock';
  if FileExists(FPath) then
  begin
    Message := 'lock already held: ' + FPath;
    Exit(False);
  end;
  AssignFile(F, FPath);
  try
    Rewrite(F);
    Writeln(F, GetProcessID);
    CloseFile(F);
    FHeld := True;
    Result := True;
  except
    on E: Exception do
    begin
      Message := 'cannot create lock ' + FPath + ': ' + E.Message;
      Result := False;
    end;
  end;
end;

procedure TAppLock.Release;
begin
  if FHeld and (FPath <> '') and FileExists(FPath) then
    DeleteFile(FPath);
  FHeld := False;
end;

destructor TAppLock.Destroy;
begin
  Release;
  inherited Destroy;
end;

end.
