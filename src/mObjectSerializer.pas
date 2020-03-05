unit mObjectSerializer;

interface

uses System.Classes, System.Rtti;

type

  TClassFactory = reference to function(aClassName: string): TObject;

  IObjectSerializer = interface
    function ObjectToString(aObj: TObject): string;
    function StringToObject(aStr: String): TObject;
    function CloneObject(aObj: TObject): TObject;
  end;

  TObjectSerializer = class abstract(TInterfacedObject, IObjectSerializer)
  private
    FClassFactory: TClassFactory;
    FClassStore: TArray<TClass>;
    function FindClass(aQualifiedClassName: string): TClass;
  private
    function CreateInstance(aClass: TClass): TObject; overload;
    function CreateInstance(aQualifiedClassName: string): TObject; overload;
    function CreateInstance(LClass: TRttiInstanceType): TObject; overload;
  protected
    procedure AddClass(aClass: TClass);
    function CreateObject(aQualifiedClassName: string): TObject;
  public
    function ObjectToString(aObj: TObject): string; virtual; abstract;
    function StringToObject(aStr: String): TObject; virtual; abstract;
    function CloneObject(aObj: TObject): TObject; virtual; abstract;
    constructor Create(aClassFactory: TClassFactory = nil);
  end;

  TJsonObjectSerializer = class(TObjectSerializer)
  public
    function ObjectToString(aObj: TObject): string; override;
    function StringToObject(aStr: String): TObject; override;
    function CloneObject(aObj: TObject): TObject; override;
  end;

implementation

uses Json, Rest.Json, SysUtils;

const
  StrClassName = 'ClassName';
  StrData = 'Data';

function TObjectSerializer.CreateInstance(aClass: TClass): TObject;
var
  LContext: TRttiContext;
  LClass: TRttiInstanceType;
begin
  LContext := TRttiContext.Create();
  try
    LClass := LContext.GetType(aClass) as TRttiInstanceType;
    Result := CreateInstance(LClass);
  finally
    LContext.Free;
  end;
end;

function TObjectSerializer.CreateInstance(aQualifiedClassName: string): TObject;
var
  LContext: TRttiContext;
  LClass: TRttiInstanceType;
begin
  LContext := TRttiContext.Create();
  try
    LClass := LContext.FindType(aQualifiedClassName) as TRttiInstanceType;
    Result := CreateInstance(LClass);
  finally
    LContext.Free;
  end;
end;

procedure TObjectSerializer.AddClass(aClass: TClass);
begin
  // классы сохраняем, так как достать по имени не публичные классы через rtti невозможно
  if FindClass(aClass.QualifiedClassName) = nil then
    FClassStore := FClassStore + [aClass];
end;

constructor TObjectSerializer.Create(aClassFactory: TClassFactory);
begin
  FClassFactory := aClassFactory;
end;

function TObjectSerializer.CreateInstance(LClass: TRttiInstanceType): TObject;
var
  mType: TRTTIMethod;
  metaClass: TClass;
begin
  Result := nil;

  if not Assigned(LClass) then
    Exit;

  for mType in LClass.GetMethods do
    if mType.HasExtendedInfo and mType.IsConstructor then
      if Length(mType.GetParameters) = 0 then
      begin
        metaClass := LClass.AsInstance.MetaclassType;
        Result := (mType.Invoke(metaClass, []).AsObject);
        Exit;
      end;
end;

function TObjectSerializer.CreateObject(aQualifiedClassName: string): TObject;
var
  vClass: TClass;
begin

  // сначала создаем правильно через конструктор в явном виде (конструктор может быть с параметрами)
  if Assigned(FClassFactory) then
    Result := FClassFactory(aQualifiedClassName)
  else
    Result := nil;

  if not Assigned(Result) then
  begin
    // потом уже грязные хаки с rtti
    vClass := FindClass(aQualifiedClassName);
    if Assigned(vClass) then
      Result := CreateInstance(vClass)
    else
      Result := CreateInstance(aQualifiedClassName);
  end;

end;

function TObjectSerializer.FindClass(aQualifiedClassName: string): TClass;
var
  c: TClass;
begin
  for c in FClassStore do
    if SameStr(c.QualifiedClassName, aQualifiedClassName) then
      Exit(c);
  Result := nil;
end;

function TJsonObjectSerializer.CloneObject(aObj: TObject): TObject;
var
  jObj: TJSONObject;
begin
  Result := nil;
  jObj := TJson.ObjectToJsonObject(aObj);
  if Assigned(jObj) then
    try
      Result := CreateObject(aObj.QualifiedClassName);
      TJson.JsonToObject(Result, jObj);
    finally
      jObj.Free;
    end;

end;

function TJsonObjectSerializer.ObjectToString(aObj: TObject): string;
var
  jObj: TJSONObject;
begin
  AddClass(aObj.ClassType);

  jObj := TJSONObject.Create;
  try
    jObj.AddPair(StrClassName, aObj.ClassType.QualifiedClassName);
    jObj.AddPair(StrData, TJson.ObjectToJsonObject(aObj));
{$IFNDEF DEBUG}
    Result := jObj.Format
{$ELSE}
    Result := jObj.ToString;
{$ENDIF}
  finally
    jObj.Free;
  end;
end;

function TJsonObjectSerializer.StringToObject(aStr: String): TObject;
var
  jObj, jData: TJSONObject;
  jVal: TJSONValue;
  ClassName: string;
begin
  Result := nil;
  jVal := TJSONObject.ParseJSONValue(aStr);
  if Assigned(jVal) then
    if jVal is TJSONObject then
      try
        jObj := TJSONObject(jVal);
        if jObj.TryGetValue<string>(StrClassName, ClassName) then
        begin
          Result := CreateObject(ClassName);
          if Assigned(Result) then
            if jObj.TryGetValue<TJSONObject>(StrData, jData) then
              TJson.JsonToObject(Result, jData);
        end;
      finally
        jVal.Free;
      end;
end;

end.
