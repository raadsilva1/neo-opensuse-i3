unit checksum;

{$mode objfpc}{$H+}

interface

function SHA256File(const Path: string): string;

implementation

uses
  SysUtils, models, process_runner;

function SHA256File(const Path: string): string;
var
  R: TCommandResult;
  P: Integer;
begin
  Result := '';
  if not FileExists(Path) then Exit;
  R := RunCommand('/usr/bin/env', ['sha256sum', Path]);
  if R.ExitCode <> 0 then Exit;
  P := Pos(' ', R.Output);
  if P > 1 then
    Result := Copy(R.Output, 1, P - 1);
end;

end.
