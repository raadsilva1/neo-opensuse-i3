unit process_runner;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Process, models;

function CommandExists(const Name: string): Boolean;
function RunCommand(const Exe: string; const Args: array of string; TimeoutSeconds: Integer = 0): TCommandResult;
function RunShell(const Command: string): TCommandResult;

implementation

function CommandExists(const Name: string): Boolean;
var
  R: TCommandResult;
begin
  R := RunCommand('/usr/bin/env', ['sh', '-c', 'command -v ' + ShellQuote(Name) + ' >/dev/null 2>&1']);
  Result := R.ExitCode = 0;
end;

function RunCommand(const Exe: string; const Args: array of string; TimeoutSeconds: Integer): TCommandResult;
var
  P: TProcess;
  Buffer: array[0..4095] of Byte;
  Count: LongInt;
  I: Integer;
  Started: TDateTime;
  Chunk: string;
begin
  Result.ExitCode := 127;
  Result.Output := '';
  P := TProcess.Create(nil);
  try
    P.Executable := Exe;
    for I := 0 to High(Args) do
      P.Parameters.Add(Args[I]);
    P.Options := [poUsePipes, poStderrToOutPut];
    Started := Now;
    try
      P.Execute;
      while P.Running do
      begin
        while P.Output.NumBytesAvailable > 0 do
        begin
          Count := P.Output.Read(Buffer, SizeOf(Buffer));
          if Count > 0 then
          begin
            SetString(Chunk, PChar(@Buffer[0]), Count);
            Result.Output := Result.Output + Chunk;
          end;
        end;
        if (TimeoutSeconds > 0) and (((Now - Started) * 86400) > TimeoutSeconds) then
        begin
          P.Terminate(124);
          Break;
        end;
        Sleep(20);
      end;
      while P.Output.NumBytesAvailable > 0 do
      begin
        Count := P.Output.Read(Buffer, SizeOf(Buffer));
        if Count > 0 then
        begin
          SetString(Chunk, PChar(@Buffer[0]), Count);
          Result.Output := Result.Output + Chunk;
        end;
      end;
      Result.ExitCode := P.ExitStatus;
    except
      on E: Exception do
      begin
        Result.ExitCode := 127;
        Result.Output := E.Message;
      end;
    end;
  finally
    P.Free;
  end;
end;

function RunShell(const Command: string): TCommandResult;
begin
  Result := RunCommand('/usr/bin/env', ['sh', '-c', Command]);
end;

end.
