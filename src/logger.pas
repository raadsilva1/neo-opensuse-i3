unit logger;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, constants, json_writer;

type
  TLogger = class
  private
    FTextPath: string;
    FJsonPath: string;
    FText: TextFile;
    FJson: TextFile;
    FOpen: Boolean;
    FJsonOpen: Boolean;
    FFirstJson: Boolean;
  public
    constructor Create;
    destructor Destroy; override;
    function Open(const RequestedPath: string; const DryRun: Boolean; out Warning: string): Boolean;
    procedure Info(const Msg: string);
    procedure Warn(const Msg: string);
    procedure Error(const Msg: string);
    procedure Event(const Level, Msg: string);
    procedure WriteStructuredJson(const Content: string);
    property TextPath: string read FTextPath;
    property JsonPath: string read FJsonPath;
  end;

function Timestamp: string;
function RunStamp: string;

implementation

function Timestamp: string;
begin
  Result := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
end;

function RunStamp: string;
begin
  Result := FormatDateTime('yyyymmdd-hhnnss', Now);
end;

constructor TLogger.Create;
begin
  inherited Create;
  FOpen := False;
  FJsonOpen := False;
  FFirstJson := True;
end;

destructor TLogger.Destroy;
begin
  if FOpen then
  begin
    if FJsonOpen then
    begin
      Writeln(FJson);
      Writeln(FJson, ']}');
      CloseFile(FJson);
    end;
    CloseFile(FText);
  end;
  inherited Destroy;
end;

function EnsureLogDir(const Dir: string): Boolean;
begin
  Result := ForceDirectories(Dir);
end;

function TLogger.Open(const RequestedPath: string; const DryRun: Boolean; out Warning: string): Boolean;
var
  Base, Stamp: string;
begin
  Warning := '';
  Stamp := RunStamp;
  if RequestedPath <> '' then
  begin
    FTextPath := ExpandFileName(RequestedPath);
    FJsonPath := ChangeFileExt(FTextPath, '.json');
    Base := ExtractFileDir(FTextPath);
    if (Base <> '') and (not EnsureLogDir(Base)) then
    begin
      Warning := 'cannot create log directory: ' + Base;
      Exit(False);
    end;
  end
  else
  begin
    Base := '/var/log/' + AppName;
    if not EnsureLogDir(Base) then
    begin
      Base := GetTempDir(False) + AppName;
      Warning := 'using fallback log directory ' + Base + ' because /var/log is not writable';
      if not EnsureLogDir(Base) then
        Exit(False);
    end;
    FTextPath := Base + DirectorySeparator + 'install-' + Stamp + '.log';
    FJsonPath := Base + DirectorySeparator + 'install-' + Stamp + '.json';
  end;
  AssignFile(FText, FTextPath);
  Rewrite(FText);
  AssignFile(FJson, FJsonPath);
  Rewrite(FJson);
  Writeln(FJson, '{"events":[');
  FJsonOpen := True;
  FOpen := True;
  Info(AppName + ' ' + AppVersion + ' log started');
  Result := True;
end;

procedure TLogger.Event(const Level, Msg: string);
begin
  if not FOpen then Exit;
  Writeln(FText, Timestamp, ' [', Level, '] ', Msg);
  Flush(FText);
  if not FJsonOpen then Exit;
  if not FFirstJson then
    Writeln(FJson, ',')
  else
    FFirstJson := False;
  Write(FJson, '  {"time":"', JsonEscape(Timestamp), '","level":"', JsonEscape(Level),
    '","message":"', JsonEscape(Msg), '"}');
  Flush(FJson);
end;

procedure TLogger.WriteStructuredJson(const Content: string);
var
  F: TextFile;
begin
  if FJsonOpen then
  begin
    Writeln(FJson);
    Writeln(FJson, ']}');
    CloseFile(FJson);
    FJsonOpen := False;
  end;
  AssignFile(F, FJsonPath);
  Rewrite(F);
  Write(F, Content);
  CloseFile(F);
end;

procedure TLogger.Info(const Msg: string);
begin
  Event('info', Msg);
end;

procedure TLogger.Warn(const Msg: string);
begin
  Event('warning', Msg);
end;

procedure TLogger.Error(const Msg: string);
begin
  Event('error', Msg);
end;

end.
