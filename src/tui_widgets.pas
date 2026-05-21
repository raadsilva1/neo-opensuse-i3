unit tui_widgets;

{$mode objfpc}{$H+}

interface

procedure PrintStatus(const LabelText, StateText, Detail: string; Plain: Boolean);

implementation

uses
  SysUtils, tui_theme;

procedure PrintStatus(const LabelText, StateText, Detail: string; Plain: Boolean);
var
  Color: string;
begin
  if Plain then
  begin
    Writeln('[', StateText, '] ', LabelText, ' - ', Detail);
    Exit;
  end;
  Color := CGreen;
  if StateText = 'failed' then Color := CRed
  else if (StateText = 'warning') or (StateText = 'skipped') then Color := CYellow
  else if StateText = 'running' then Color := CBrightGreen;
  Writeln(Color, '[', StateText, ']', CReset, ' ', CBold, LabelText, CReset, ' ', Detail);
end;

end.
