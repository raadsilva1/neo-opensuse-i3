unit package_resolver;

{$mode objfpc}{$H+}

interface

uses
  SysUtils, models, logger, gpu_detect;

function ResolvePackages(const Options: TCLIOptions; const GPU: TGPUInfo; Log: TLogger; out Decisions: TPackageDecisionArray; out MissingRequired, ToInstall: TStringArray): Boolean;

implementation

uses
  zypper;

procedure AddDecision(var Decisions: TPackageDecisionArray; const Name, GroupName: string; Required: Boolean; Log: TLogger; var MissingRequired, ToInstall: TStringArray);
var
  D: TPackageDecision;
begin
  D.Name := Name;
  D.GroupName := GroupName;
  D.Required := Required;
  D.Installed := PackageInstalled(Name);
  D.Candidate := D.Installed or PackageCandidateExists(Name);
  D.Selected := D.Candidate and not D.Installed;
  if D.Installed then D.Reason := 'already installed'
  else if D.Candidate then D.Reason := 'candidate available'
  else if Required then D.Reason := 'required package has no repository candidate'
  else D.Reason := 'optional package has no repository candidate';
  SetLength(Decisions, Length(Decisions) + 1);
  Decisions[High(Decisions)] := D;
  if D.Selected then AddString(ToInstall, Name);
  if Required and not D.Candidate then AddString(MissingRequired, Name);
  if Assigned(Log) then
    Log.Info('package ' + Name + ' [' + GroupName + ']: ' + D.Reason);
end;

function HasDecision(const Decisions: TPackageDecisionArray; const Name: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to High(Decisions) do
    if Decisions[I].Name = Name then
      Exit(True);
end;

function ResolvePackages(const Options: TCLIOptions; const GPU: TGPUInfo; Log: TLogger; out Decisions: TPackageDecisionArray; out MissingRequired, ToInstall: TStringArray): Boolean;
const
  XorgRequiredPkgs: array[0..21] of string = (
    'i3', 'bemenu', 'ghostty', 'kitty', 'feh', 'scrot', 'i3lock', 'brightnessctl', 'xset', 'xrandr',
    'xinit', 'xauth', 'dbus-1', 'pipewire', 'wireplumber',
    'google-noto-sans-fonts', 'google-noto-coloremoji-fonts',
    'Mesa', 'Mesa-dri', 'Mesa-libGL1', 'Mesa-libEGL1', 'libvulkan1');
  XorgOptionalPkgs: array[0..0] of string = ('alacritty');
  WaylandRequiredPkgs: array[0..18] of string = (
    'sway', 'fuzzel', 'ghostty', 'kitty', 'grim', 'slurp', 'swaylock', 'swaybg',
    'brightnessctl', 'wl-clipboard', 'dbus-1', 'pipewire', 'wireplumber',
    'google-noto-sans-fonts', 'google-noto-coloremoji-fonts',
    'Mesa', 'Mesa-dri', 'Mesa-libEGL1', 'libvulkan1');
  WaylandOptionalPkgs: array[0..1] of string = ('alacritty', 'mako');
var
  I: Integer;
begin
  SetLength(Decisions, 0);
  SetLength(MissingRequired, 0);
  SetLength(ToInstall, 0);
  if Options.Wayland then
  begin
    for I := Low(WaylandRequiredPkgs) to High(WaylandRequiredPkgs) do
      AddDecision(Decisions, WaylandRequiredPkgs[I], 'required', True, Log, MissingRequired, ToInstall);
    for I := Low(WaylandOptionalPkgs) to High(WaylandOptionalPkgs) do
      AddDecision(Decisions, WaylandOptionalPkgs[I], 'recommended', False, Log, MissingRequired, ToInstall);
  end
  else
  begin
    for I := Low(XorgRequiredPkgs) to High(XorgRequiredPkgs) do
      AddDecision(Decisions, XorgRequiredPkgs[I], 'required', True, Log, MissingRequired, ToInstall);
    for I := Low(XorgOptionalPkgs) to High(XorgOptionalPkgs) do
      AddDecision(Decisions, XorgOptionalPkgs[I], 'recommended', False, Log, MissingRequired, ToInstall);
  end;
  for I := 0 to High(GPU.Packages) do
    if not HasDecision(Decisions, GPU.Packages[I]) then
      AddDecision(Decisions, GPU.Packages[I], 'platform', False, Log, MissingRequired, ToInstall);
  Result := Length(MissingRequired) = 0;
end;

end.
