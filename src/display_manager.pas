unit display_manager;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, logger;

type
  TDisplayManagerInfo = record
    Name: string;
    Running: Boolean;
    Detail: string;
  end;

function DetectDisplayManager(Log: TLogger): TDisplayManagerInfo;

implementation

uses
  models, process_runner;

function DetectDisplayManager(Log: TLogger): TDisplayManagerInfo;
var
  R: TCommandResult;
begin
  Result.Name := 'unknown';
  Result.Running := False;
  Result.Detail := 'no display manager detected';
  if CommandExists('systemctl') then
  begin
    R := RunCommand('/usr/bin/env', ['systemctl', 'is-active', 'display-manager.service']);
    Result.Running := Trim(R.Output) = 'active';
    R := RunCommand('/usr/bin/env', ['systemctl', 'show', '-p', 'Id', '-p', 'Names', 'display-manager.service']);
    Result.Detail := Trim(R.Output);
    if Pos('gdm', LowerCase(R.Output)) > 0 then Result.Name := 'GDM'
    else if Pos('sddm', LowerCase(R.Output)) > 0 then Result.Name := 'SDDM'
    else if Pos('lightdm', LowerCase(R.Output)) > 0 then Result.Name := 'LightDM'
    else if Pos('xdm', LowerCase(R.Output)) > 0 then Result.Name := 'XDM';
  end;
  if Assigned(Log) then
    Log.Info('display manager: ' + Result.Name + ', running=' + BoolText(Result.Running) + ', ' + Result.Detail);
end;

end.
