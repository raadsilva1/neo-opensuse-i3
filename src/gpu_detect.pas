unit gpu_detect;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, models, logger;

type
  TGPUInfo = record
    Summary: string;
    Packages: TStringArray;
    Warnings: TStringArray;
  end;

function DetectGPU(const Options: TCLIOptions; Log: TLogger): TGPUInfo;

implementation

uses
  process_runner;

procedure AddPkg(var Info: TGPUInfo; const Pkg: string);
begin
  if not ContainsString(Info.Packages, Pkg) then
    AddString(Info.Packages, Pkg);
end;

function DetectGPU(const Options: TCLIOptions; Log: TLogger): TGPUInfo;
var
  R: TCommandResult;
  L: string;
begin
  Result.Summary := 'unknown GPU/platform';
  SetLength(Result.Packages, 0);
  SetLength(Result.Warnings, 0);
  AddPkg(Result, 'Mesa');
  AddPkg(Result, 'Mesa-dri');
  AddPkg(Result, 'Mesa-libGL1');
  AddPkg(Result, 'Mesa-libEGL1');
  AddPkg(Result, 'libvulkan1');
  R := RunCommand('/usr/bin/env', ['sh', '-c', 'lspci 2>/dev/null | grep -Ei ''vga|3d|display'' || true']);
  L := LowerCase(R.Output);
  if Pos('intel', L) > 0 then
  begin
    Result.Summary := 'Intel graphics';
    AddPkg(Result, 'intel-media-driver');
  end;
  if Pos('amd', L) > 0 then
  begin
    if Result.Summary <> 'unknown GPU/platform' then Result.Summary := Result.Summary + ', AMD graphics'
    else Result.Summary := 'AMD graphics';
    AddPkg(Result, 'Mesa-gallium');
  end;
  if Pos('nvidia', L) > 0 then
  begin
    if Result.Summary <> 'unknown GPU/platform' then Result.Summary := Result.Summary + ', NVIDIA graphics'
    else Result.Summary := 'NVIDIA graphics';
    case Options.NvidiaPolicy of
      npNouveau:
        begin
          AddPkg(Result, 'Mesa-dri-nouveau');
          AddString(Result.Warnings, 'NVIDIA detected: using Mesa/nouveau path; no repositories or boot settings changed');
        end;
      npProprietaryPrompt:
        AddString(Result.Warnings, 'NVIDIA proprietary policy selected, but repositories are not added automatically');
      npSkip:
        AddString(Result.Warnings, 'NVIDIA detected: platform-specific driver packages skipped');
    end;
  end;
  if Pos('virtualbox', L) > 0 then begin Result.Summary := 'VirtualBox graphics'; if not Options.Wayland then AddPkg(Result, 'virtualbox-guest-x11'); end;
  if Pos('vmware', L) > 0 then begin Result.Summary := 'VMware graphics'; if not Options.Wayland then AddPkg(Result, 'xf86-video-vmware'); end;
  if (Pos('virtio', L) > 0) or (Pos('qxl', L) > 0) then begin Result.Summary := 'QEMU/KVM virtual graphics'; if not Options.Wayland then AddPkg(Result, 'xf86-video-virtio'); end;
  if Assigned(Log) then
  begin
    Log.Info('GPU detection: ' + Result.Summary);
    Log.Info('GPU package candidates: ' + JoinStrings(Result.Packages, ', '));
    if Length(Result.Warnings) > 0 then Log.Warn(JoinStrings(Result.Warnings, '; '));
  end;
end;

end.
