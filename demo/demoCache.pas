unit demoCache;

interface

procedure cDemo1;

implementation

uses mCache;

procedure cDemo1;
var
  m: TMemCache<Integer, Integer>;
  i: Integer;
  v: Integer;
begin
  m := TMemCache<Integer, Integer>.Create(10);
  try
    for i := 0 to 11 do
      m.SetToCache(i, i + 1000);
    for i := 11 downto 0 do
      if m.Exist(i) then
      begin
        v := m.GetFromCache(i);
        Writeln('from cache key: ', i, ' value ', v);
      end
      else
        Writeln('miss cache ');
  finally
    m.Free;
  end;
end;

end.
