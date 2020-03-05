unit mCache;

{
  пример реализации многоуровневого кеша. для простых типов.
}
interface

uses System.Generics.Collections, System.Generics.Defaults, System.Threading;

type

  TsValue = string;

  TCacheStrategy = (csLastUse, csFrequency);

  TCache<TKey, TValue> = class
  protected type

    TCacheItem = class
      Owner: TCache<TKey, TValue>;
      Key: TKey;
      HitCount: Integer;
      LastAccess: Integer;
      function KeyAsString: string;
      function ValueAsString(const Value: TValue): string;
      procedure Assign(p: TCacheItem);
      procedure Put(const Value: TValue); virtual; abstract;
      function Get: TValue; virtual; abstract;
      procedure Del; virtual; abstract;
      procedure Hit;
      destructor Destroy; override;
    end;

    TCacheItemClass = class of TCacheItem;

    TItems = class(TObjectList<TCacheItem>)
      FKeyComparer: IComparer<TKey>;
      function byKey(const Key: TKey): TCacheItem;
      constructor Create;
    end;

  procedure AddLayer(cache: TCache<TKey, TValue>);
  private
    FItems: TItems;
    FCacheItemClass: TCacheItemClass;
    FNextCache: TCache<TKey, TValue>;
    FPrevCache: TCache<TKey, TValue>;
    FTimer: Integer;
    FCacheStrategy: TCacheStrategy;
    FSize: Integer;
    procedure SetCacheStrategy(const Value: TCacheStrategy);
    function CreateCasheItem(const Key: TKey; Owner: TCache<TKey, TValue>)
      : TCacheItem;
    function Compare(const Left, Right: TCacheItem): Integer;
    function Weakest: TCacheItem;
    function FindByKey(const Key: TKey): TCacheItem;
    procedure Push;
    procedure Pop(p: TCacheItem);
    procedure Swap<T>(var a, b: T);
    function AddToCache(const Key: TKey; const Value: TValue): TCacheItem;
    procedure Exchange(p1, p2: TCacheItem);
    function GetTimer(delta: Integer): Integer;
  public
    property CacheStrategy: TCacheStrategy read FCacheStrategy
      write SetCacheStrategy;

    procedure SetToCache(const Key: TKey; const Value: TValue);
    procedure Remove(const Key: TKey);
    function GetFromCache(const Key: TKey): TValue;
    function Exist(const Key: TKey): Boolean;
  public

    constructor Create(Size: Integer);
    destructor Destroy; override;
  public
{$IFDEF DEBUG}
    procedure Dump(var log: Tarray<String>);
{$ENDIF}
  end;

  TMemCache<TKey, TValue> = class(TCache<TKey, TValue>)
  protected type
    TMemCacheItem = class(TCacheItem)
      Data: TValue;
      procedure Put(const Value: TValue); override;
      function Get: TValue; override;
      procedure Del; override;
    end;
  public
    constructor Create(Size: Integer);
  end;

  TFileCache<TKey> = class(TCache<TKey, string>)
  private
    FCacheDir: string;
  protected type
    TValue = string;
    TFileCacheItem = class(TCacheItem)
      FFileName: string;
      function GetUnicFileName: string;
      procedure Put(const Value: TValue); override;
      function Get: TValue; override;
      procedure Del; override;
    end;
  public
    constructor Create(Size: Integer; CacheDir: string = '');
  end;

  TAsyncFileCache<TKey> = class(TFileCache<TKey>)
  protected type
    TAsyncFileCacheItem = class(TFileCacheItem)
      State: IFuture<Boolean>;
      procedure CheckState;
      procedure Put(const Value: TValue); override;
      function Get: TValue; override;
      procedure Del; override;
    end;
  public
    constructor Create(Size: Integer; CacheDir: string = '');
  end;

implementation

uses SysUtils, RTTI, IOUtils;

{ TCache<TKey> }
procedure TCache<TKey, TValue>.SetCacheStrategy(const Value: TCacheStrategy);
begin
  FCacheStrategy := Value;
  if FNextCache <> nil then
    FNextCache.SetCacheStrategy(FCacheStrategy);
end;

procedure TCache<TKey, TValue>.AddLayer(cache: TCache<TKey, TValue>);
begin
  if FNextCache = nil then
  begin
    FNextCache := cache;
    cache.FPrevCache := Self;
  end
  else
    FNextCache.AddLayer(cache);
end;

function TCache<TKey, TValue>.AddToCache(const Key: TKey; const Value: TValue)
  : TCacheItem;
begin

  Push;

  Result := CreateCasheItem(Key, Self);
  Result.Put(Value);
end;

function TCache<TKey, TValue>.Compare(const Left, Right: TCacheItem): Integer;
begin

  case FCacheStrategy of
    csLastUse:
      Result := Left.LastAccess - Right.LastAccess;
    csFrequency:
      Result := Left.HitCount - Right.HitCount;
  else
    Result := 0;
  end;
end;

constructor TCache<TKey, TValue>.Create;
begin
  FSize := Size;
  FItems := TItems.Create;
end;

function TCache<TKey, TValue>.CreateCasheItem(const Key: TKey;
  Owner: TCache<TKey, TValue>): TCacheItem;
begin
  Result := FCacheItemClass.Create;
  Result.Key := Key;
  Result.Owner := Owner;
  Result.HitCount := 0;
  Result.LastAccess := GetTimer(0);
  FItems.Add(Result);
end;

destructor TCache<TKey, TValue>.Destroy;
begin
  FItems.Free;
  if FNextCache <> nil then
    FNextCache.Free;
  inherited;
end;

{$IFDEF DEBUG}

procedure TCache<TKey, TValue>.Dump(var log: Tarray<String>);
var
  p: TCacheItem;
  Data: string;
begin
  log := log + ['   ' + Self.ClassName];
  for p in FItems do
  begin
    Data := p.ValueAsString(p.Get);
    log := log + [Format('key: %s hit: %d last: %d data: %s',
      [p.KeyAsString, p.HitCount, p.LastAccess, Data])];
  end;

  if FNextCache <> nil then
    FNextCache.Dump(log);
end;
{$ENDIF}

procedure TCache<TKey, TValue>.Exchange(p1, p2: TCacheItem);
var
  v1, v2: TValue;
begin
  if p1.Owner = p2.Owner then
    Exit;

  Swap<TKey>(p1.Key, p2.Key); //
  Swap<Integer>(p1.HitCount, p2.HitCount); //
  Swap<Integer>(p1.LastAccess, p2.LastAccess);

  v1 := p1.Get;
  v2 := p2.Get;
  p1.Del;
  p2.Del;
  p1.Put(v2);
  p2.Put(v1);
end;

function TCache<TKey, TValue>.Exist(const Key: TKey): Boolean;
begin
  Result := FindByKey(Key) <> nil;
end;

function TCache<TKey, TValue>.FindByKey(const Key: TKey): TCacheItem;
begin
  Result := FItems.byKey(Key);
  if Result = nil then
    if FNextCache <> nil then
      Result := FNextCache.FindByKey(Key);
end;

function TCache<TKey, TValue>.GetFromCache(const Key: TKey): TValue;
var
  p: TCacheItem;
begin
  p := FindByKey(Key);
  if p = nil then
    raise Exception.Create('Not found item ' + p.KeyAsString);
  Result := p.Get;
  p.Hit;
  Pop(p);
end;

function TCache<TKey, TValue>.GetTimer(delta: Integer): Integer;
begin
  if FPrevCache = nil then
  begin
    FTimer := FTimer + delta;
    Result := FTimer;
  end
  else
    Result := FPrevCache.GetTimer(delta);
end;

procedure TCache<TKey, TValue>.Pop(p: TCacheItem);
var
  tmp: TCacheItem;
begin
  if p.Owner.FPrevCache = nil then
    Exit;
  tmp := p.Owner.FPrevCache.Weakest;
  if Compare(p, tmp) > 0 then
    Exchange(p, tmp);
end;

procedure TCache<TKey, TValue>.Push;
var
  p: TCacheItem;
begin
  if FItems.Count < FSize then
    Exit;
  p := Weakest;
  if FNextCache <> nil then
  begin
    FNextCache.AddToCache(p.Key, p.Get).Assign(p);
  end;

  Remove(p.Key);
end;

procedure TCache<TKey, TValue>.Remove(const Key: TKey);
var
  p: TCacheItem;
begin
  p := FindByKey(Key);
  Assert(p <> nil, 'Не нашли');
  p.Del;
  p.Owner.FItems.Remove(p);
end;

procedure TCache<TKey, TValue>.SetToCache(const Key: TKey; const Value: TValue);
var
  p: TCacheItem;
begin
  p := FindByKey(Key);
  if p <> nil then
  begin // элемент уже есть
    p.Del;
    p.Put(Value);
    p.Hit;
    Exit;
  end;

  AddToCache(Key, Value).Hit;

end;

procedure TCache<TKey, TValue>.Swap<T>(var a, b: T);
var
  c: T;
begin
  c := a;
  a := b;
  b := c;
end;

{ TCache.TItemInfo }

procedure TCache<TKey, TValue>.TCacheItem.Assign(p: TCacheItem);
begin
  LastAccess := p.LastAccess;
  HitCount := p.HitCount;
end;

destructor TCache<TKey, TValue>.TCacheItem.Destroy;
begin
  Del;
  inherited;
end;

procedure TCache<TKey, TValue>.TCacheItem.Hit;
begin
  HitCount := HitCount + 1;
  LastAccess := Owner.GetTimer(+1);
end;

function TCache<TKey, TValue>.TCacheItem.KeyAsString: string;
begin
  Result := RTTI.TValue.From<TKey>(Key).ToString;
end;

function TCache<TKey, TValue>.TCacheItem.ValueAsString
  (const Value: TValue): string;
begin
  Result := RTTI.TValue.From<TValue>(Value).ToString;
end;

{ TMemCache.TMemItemInfo }

procedure TMemCache<TKey, TValue>.TMemCacheItem.Del;
begin
  Data := default (TValue);
end;

function TMemCache<TKey, TValue>.TMemCacheItem.Get: TValue;
begin
  Result := Data;
end;

procedure TMemCache<TKey, TValue>.TMemCacheItem.Put(const Value: TValue);
begin
  Data := Value;
end;

{ TCache.TItems }

function TCache<TKey, TValue>.TItems.byKey(const Key: TKey): TCacheItem;
var
  p: TCacheItem;
begin
  for p in Self do
    if FKeyComparer.Compare(p.Key, Key) = 0 then
      Exit(p);
  Result := nil;
end;

function TCache<TKey, TValue>.Weakest: TCacheItem;
var
  i: Integer;
begin
  if FItems.Count = 0 then
    Exit(nil);

  Result := FItems[0];
  for i := 0 + 1 to FItems.Count - 1 do
    if Compare(Result, FItems[i]) > 0 then
    begin
      Result := FItems[i];
    end;
end;

{ TMemCache }

constructor TMemCache<TKey, TValue>.Create(Size: Integer);
begin
  inherited Create(Size);
  FCacheItemClass := TMemCacheItem;
end;

{ TFileCache<TKey, TValue>.TFileCacheItem }

procedure TFileCache<TKey>.TFileCacheItem.Del;
begin
  if TFile.Exists(FFileName) then
    TFile.Delete(FFileName);
  FFileName := '';
end;

function TFileCache<TKey>.TFileCacheItem.Get: TValue;
var
  buf: string;
  v: RTTI.TValue;
begin
 // Result := default (TValue);
  buf := TFile.ReadAllText(FFileName, TEncoding.UTF8);
  //v := buf;
  Result := buf//v.AsType<TValue>;
end;

function TFileCache<TKey>.TFileCacheItem.GetUnicFileName: string;
begin
  Result := TPath.Combine((Owner as TFileCache<TKey>).FCacheDir,
    TPath.GetGUIDFileName);
end;

procedure TFileCache<TKey>.TFileCacheItem.Put(const Value: TValue);
var
  buf: string;
begin
  FFileName := GetUnicFileName;
  buf := ValueAsString(Value);
  TFile.WriteAllText(FFileName, buf, TEncoding.UTF8);
end;

{ TFileCache<TKey, TValue> }

constructor TFileCache<TKey>.Create;
begin
  inherited Create(Size);
  FCacheItemClass := TFileCacheItem;
  FCacheDir := CacheDir;
  if FCacheDir.IsEmpty then
    FCacheDir := TPath.GetTempPath;
  TDirectory.CreateDirectory(FCacheDir);
end;

{ TAsyncFileCache<TKey, TValue> }

constructor TAsyncFileCache<TKey>.Create(Size: Integer;
  CacheDir: string);
begin
  inherited;
  FCacheItemClass := TAsyncFileCacheItem;
end;

{ TAsyncFileCache<TKey, TValue>.TAsyncFileCacheItem }

procedure TAsyncFileCache<TKey>.TAsyncFileCacheItem.CheckState;
begin
  if Assigned(State) then
    State.Value;
end;

procedure TAsyncFileCache<TKey>.TAsyncFileCacheItem.Del;
begin
  CheckState;
  inherited;
end;

function TAsyncFileCache<TKey>.TAsyncFileCacheItem.Get: TValue;
begin
  CheckState;
  Result := inherited;
end;

procedure TAsyncFileCache<TKey>.TAsyncFileCacheItem.Put
  (const Value: TValue);
begin
  CheckState;
  // немного многопоточки для отзывчивости.
  State := TTask.Future<Boolean>(
    function: Boolean
    begin
      inherited Put(Value);
      Result := True;
    end);
end;

constructor TCache<TKey, TValue>.TItems.Create;
begin
  inherited Create;
  FKeyComparer := TComparer<TKey>.default;
end;

end.
