unit demoObjectCache;

interface

procedure Demo;
procedure Demo2;
procedure Demo3;

implementation

uses mObjectCache, demoObject, SysUtils, Generics.Collections,
  System.Diagnostics;

procedure writeDump(cache: TObjectMemCache);
var
  l: TArray<string>;
  st: string;
begin
  l := [];
{$IFDEF DEBUG}
  cache.Dump(l);
{$ENDIF}
  Writeln(string.Create('=', 80));
  for st in l do
    Writeln(st);
  Writeln(string.Create('=', 80));
end;

function MonthDBdemo(c: TObjectMemCache): Int64;
var
  mc: TMonthObject;
  i, j: Integer;
  key: string;
  timer: TStopwatch;
begin
  timer := TStopwatch.StartNew;

  for j := 0 to 9 do
  begin
   // Writeln('================ Step ', j:2, ' ==================');
    for i := 1 to 12 do
    begin
      key := FormatSettings.LongMonthNames[i];
      if c.Exist(key) then
      begin
        mc := c.GetFromCache<TMonthObject>(key);
      //  Writeln('from cache ', key, ' ', mc.MonthName);
      end
      else
      begin
        mc := GetMonthFromDB(i);
        c.SetToCache(key, mc);
      //  Writeln('from DB ', key, ' ', mc.MonthName);
      end;
      Assert(mc.MonthName = key);
      mc.Free;
    end;
  end;

  timer.Stop;
  Result := timer.ElapsedMilliseconds;
end;

procedure Demo;

var
  c1, c2: TObjectMemCache;
  i: Integer;
begin
  // если поставить размер кеша меньше 12 то в него не разу не попадем. бывает.
  // до 12 постоянная запись на диск.
  c1 := nil;
  c2 := nil;
  for i := 1 to 15 do
    try
      c1 := TObjectMemFileCache.Create(i, 100);
      c2 := TObjectMemAsyncFileCache.Create(i, 100);
      Writeln(i:3, '  ', //
        c1.ClassName, '  ', MonthDBdemo(c1), ' мс  ', //
        c2.ClassName, '  ', MonthDBdemo(c2), ' мс');
    finally
      FreeAndNil(c1);
      FreeAndNil(c2);
    end;
  // итого  TObjectAsyncCache чуть быстрее, мелочь но приятно
end;

procedure Demo2;
var
  c: TObjectMemFileCache;

type
  TDemoDict = TDictionary<Integer, string>;
var
  d, dc1, dc2: TDemoDict;
  i: Integer;
const
  key = 'Словарь';
begin

  c := TObjectMemFileCache.Create(10, 8,

    function(aClassName: string): TObject
    begin
      // некоторые объекты надо создавать ручками, иначе получим симпатичный такой exception
      if TDemoDict.QualifiedClassName = aClassName then
        Result := TDemoDict.Create // по факту вызывается  Create(0)
      else
        Result := nil
    end);

  try

    d := TDemoDict.Create;
    try
      for i := 1 to 7 do
        d.Add(i, FormatSettings.LongDayNames[i]);
      c.SetToCache(key, d);
    finally
      d.Free;
    end;

    writeDump(c);

    dc1 := nil;
    dc2 := nil;

    try
      dc1 := c.GetFromCache<TDemoDict>(key);
      dc2 := c.GetFromCache<TDemoDict>(key);
      Write('from cache  first copy');
      for i := 1 to 7 do
        Write(' ', dc1[i]);
      Writeln;

      Write('from cache second copy');
      for i := 1 to 7 do
        Write(' ', dc2[i]);
      Writeln;
    finally
      dc1.Free;
      dc2.Free;
    end;

  finally
    c.Free;
  end;
end;

type
  TWrap = class
  private type
    TWeekObject = class
    private
      Fday: Integer;
      FDayOfWeek: string;
    public
      constructor Create(day: Word);
    end;
  end;

constructor TWrap.TWeekObject.Create(day: Word);
begin
  Assert((day >= 1) or (day <= 7));
  Fday := day;
  FDayOfWeek := FormatSettings.LongDayNames[Fday];
end;

procedure Demo3;
var
  c: TObjectMemFileCache;
  w, w2: TWrap.TWeekObject;
begin
  // работаем с объектами из implementation (rtti не находит по имени не публичные объекты )

  c := TObjectMemFileCache.Create(4, 3);
  try
    w := TWrap.TWeekObject.Create(1);
    w2 := nil;
    try
      c.SetToCache('вс', w);
      w2 := c.GetFromCache<TWrap.TWeekObject>('вс');
      Assert(w2 <> w);
      Assert(w2.FDayOfWeek = w.FDayOfWeek);
      Writeln(Format('%p->%s %p->%s', [pointer(w), w.FDayOfWeek, pointer(w2),
        w2.FDayOfWeek]));
    finally
      FreeAndNil(w);
      FreeAndNil(w2);
    end;
  finally
    c.Free;
  end;
end;

{ TWeekObject }

end.
