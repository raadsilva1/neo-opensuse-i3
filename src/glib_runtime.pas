unit glib_runtime;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, Dynlibs;

type
  TGLibStatus = record
    Available: Boolean;
    Detail: string;
  end;

function CheckGLib: TGLibStatus;

implementation

type
  TGlibCheckVersion = function(RequiredMajor, RequiredMinor, RequiredMicro: LongWord): PChar; cdecl;

function CheckGLib: TGLibStatus;
var
  Lib: TLibHandle;
  CheckVersion: TGlibCheckVersion;
  Response: PChar;
begin
  Result.Available := False;
  Result.Detail := 'libglib-2.0.so.0 not loaded';
  Lib := LoadLibrary('libglib-2.0.so.0');
  if Lib = NilHandle then
    Exit;
  try
    Pointer(CheckVersion) := GetProcAddress(Lib, 'glib_check_version');
    if not Assigned(CheckVersion) then
    begin
      Result.Detail := 'GLib loaded, glib_check_version symbol missing';
      Exit;
    end;
    Response := CheckVersion(2, 0, 0);
    Result.Available := Response = nil;
    if Result.Available then
      Result.Detail := 'GLib runtime loaded and version check passed'
    else
      Result.Detail := 'GLib runtime loaded but version check failed: ' + StrPas(Response);
  finally
    UnloadLibrary(Lib);
  end;
end;

end.
