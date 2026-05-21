unit zypper;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, models, logger;

function ZypperAvailable: Boolean;
function RepoAvailable(Log: TLogger): Boolean;
function PackageInstalled(const Name: string): Boolean;
function PackageCandidateExists(const Name: string): Boolean;
function InstallPackages(const Packages: TStringArray; DryRun: Boolean; Log: TLogger): Boolean;

implementation

uses
  Classes, process_runner;

function ZypperAvailable: Boolean;
begin
  Result := CommandExists('zypper');
end;

function RepoAvailable(Log: TLogger): Boolean;
var
  R: TCommandResult;
  Lines, Fields: TStringList;
  I: Integer;
begin
  R := RunCommand('/usr/bin/env', ['zypper', '--non-interactive', 'lr', '-u'], 30);
  Result := False;
  if R.ExitCode = 0 then
  begin
    Lines := TStringList.Create;
    Fields := TStringList.Create;
    try
      Fields.Delimiter := '|';
      Fields.StrictDelimiter := True;
      Lines.Text := R.Output;
      for I := 0 to Lines.Count - 1 do
      begin
        if Pos('|', Lines[I]) = 0 then Continue;
        Fields.DelimitedText := Lines[I];
        if (Fields.Count >= 4) and (Trim(Fields[3]) = 'Yes') then
        begin
          Result := True;
          Break;
        end;
      end;
    finally
      Fields.Free;
      Lines.Free;
    end;
  end;
  if Assigned(Log) then
    if Result then Log.Info('zypper repositories are available')
    else Log.Error('zypper repository check failed: ' + R.Output);
end;

function PackageInstalled(const Name: string): Boolean;
var
  R: TCommandResult;
begin
  R := RunCommand('/usr/bin/env', ['rpm', '-q', Name], 20);
  Result := R.ExitCode = 0;
end;

function PackageCandidateExists(const Name: string): Boolean;
var
  R: TCommandResult;
begin
  R := RunCommand('/usr/bin/env', ['zypper', '--non-interactive', '--xmlout', 'search', '--match-exact', '--type', 'package', Name], 45);
  Result := (R.ExitCode = 0) and (Pos('name="' + Name + '"', R.Output) > 0);
end;

function InstallPackages(const Packages: TStringArray; DryRun: Boolean; Log: TLogger): Boolean;
var
  Args: array of string;
  I: Integer;
  R: TCommandResult;
begin
  Result := True;
  if Length(Packages) = 0 then
  begin
    if Assigned(Log) then Log.Info('no missing packages selected for installation');
    Exit;
  end;
  if DryRun then
  begin
    if Assigned(Log) then Log.Info('dry-run package install plan: ' + JoinStrings(Packages, ', '));
    Exit(True);
  end;
  SetLength(Args, Length(Packages) + 3);
  Args[0] := 'zypper';
  Args[1] := '--non-interactive';
  Args[2] := 'install';
  for I := 0 to High(Packages) do
    Args[I + 3] := Packages[I];
  if Assigned(Log) then Log.Info('running zypper install for: ' + JoinStrings(Packages, ', '));
  R := RunCommand('/usr/bin/env', Args, 0);
  Result := R.ExitCode = 0;
  if Assigned(Log) then
    if Result then Log.Info('zypper install completed')
    else Log.Error('zypper install failed: ' + R.Output);
end;

end.
