unit mObjectCache;

interface

uses mCache, mObjectSerializer;

type

  TObjectMemCache = class(TMemCache<string>)
  private
    FSerializer: IObjectSerializer;
  public
    constructor Create(aMemSize, aHDDSize: Integer;
      ClassFactory: TClassFactory = nil); virtual;
    procedure SetToCache(const Key: string; const jObj: TObject);
    procedure Remove(const Key: string);
    function GetFromCache<T: class>(const Key: string): T;
    function Exist(const Key: string): Boolean;
  end;

  TObjectMemFileCache = class(TObjectMemCache)
    constructor Create(aMemSize, aHDDSize: Integer;
      ClassFactory: TClassFactory = nil); override;
  end;

  TObjectMemAsyncFileCache = class(TObjectMemCache)
    constructor Create(aMemSize, aHDDSize: Integer;
      ClassFactory: TClassFactory = nil); override;
  end;

  TObjectCacheClass = class of TObjectMemCache;

implementation

uses IOUtils;
{ TObjectCache }

constructor TObjectMemFileCache.Create;
begin
  inherited;

  AddLayer(TFileCache<string>.Create(aHDDSize, TPath.GetTempPath + '\ssd'));

  {
    AddLayer(TFileCache<Integer>.Create(aHDDSize,
    TPath.GetTempPath + '\hdd1'));
    AddLayer(TFileCache<Integer>.Create(aHDDSize,
    TPath.GetTempPath + '\hdd2'));
  }
end;

constructor TObjectMemCache.Create(aMemSize, aHDDSize: Integer;
  ClassFactory: TClassFactory);
begin
  inherited Create(aMemSize);

  FSerializer := TJsonObjectSerializer.Create(ClassFactory);
end;

function TObjectMemCache.Exist(const Key: string): Boolean;
begin
  Result := inherited;
end;

function TObjectMemCache.GetFromCache<T>(const Key: string): T;
begin
  if Exist(Key) then
    Result := FSerializer.StringToObject(inherited GetFromCache(Key)) as T
  else
    Result := nil;
end;

procedure TObjectMemCache.Remove(const Key: string);
begin
  inherited;
end;

procedure TObjectMemCache.SetToCache(const Key: string; const jObj: TObject);
begin
  inherited SetToCache(Key, FSerializer.ObjectToString(jObj));
end;

{ TObjectAsyncCache }

constructor TObjectMemAsyncFileCache.Create(aMemSize, aHDDSize: Integer;
  ClassFactory: TClassFactory);
begin
  inherited;

  AddLayer(TAsyncFileCache<string>.Create(aHDDSize,
    TPath.GetTempPath + '\ssd'));
end;

end.
