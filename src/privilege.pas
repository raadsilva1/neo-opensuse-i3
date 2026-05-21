unit privilege;

{$mode objfpc}{$H+}

interface

function IsRoot: Boolean;

implementation

uses
  BaseUnix;

function IsRoot: Boolean;
begin
  Result := fpGetEUid = 0;
end;

end.
