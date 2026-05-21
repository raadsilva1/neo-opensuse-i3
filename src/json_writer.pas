unit json_writer;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

function JsonEscape(const S: string): string;
function JsonPair(const Key, Value: string; IsLast: Boolean = False): string;

implementation

function JsonEscape(const S: string): string;
var
  I: Integer;
  C: Char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    case C of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
      #8: Result := Result + '\b';
      #9: Result := Result + '\t';
      #10: Result := Result + '\n';
      #12: Result := Result + '\f';
      #13: Result := Result + '\r';
    else
      if Ord(C) < 32 then
        Result := Result + '\u' + IntToHex(Ord(C), 4)
      else
        Result := Result + C;
    end;
  end;
end;

function JsonPair(const Key, Value: string; IsLast: Boolean): string;
begin
  Result := '  "' + JsonEscape(Key) + '": "' + JsonEscape(Value) + '"';
  if not IsLast then
    Result := Result + ',';
end;

end.
