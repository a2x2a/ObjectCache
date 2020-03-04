unit demoObject;

interface

type

  TMonthObject = class
  private
    FMonth: Integer;
    FMonthName: string;
    FMonthNames: TArray<string>;
    procedure SetMonth(const Value: Integer);
    procedure SetMonthName(const Value: string);
  public
    property Month: Integer read FMonth write SetMonth;
    property MonthName: string read FMonthName write SetMonthName;
    constructor Create(Month: Word);
  end;

function GetMonthFromDB(Month: Integer): TMonthObject;

implementation

uses SysUtils, DateUtils;

{ TMonthObject }

function GetMonthFromDB(Month: Integer): TMonthObject;
begin
  Result := TMonthObject.Create(Month);
end;


constructor TMonthObject.Create(Month: Word);
var
  st: string;
begin
  Assert((Month >= 1) or (Month <= 12));

  FMonth := Month;
  FMonthName := FormatSettings.LongMonthNames[FMonth];
  FMonthNames := [];
  for st in FormatSettings.LongMonthNames do
    FMonthNames := FMonthNames + [st];
end;

procedure TMonthObject.SetMonth(const Value: Integer);
begin
  FMonth := Value;
end;

procedure TMonthObject.SetMonthName(const Value: string);
begin
  FMonthName := Value;
end;

end.
