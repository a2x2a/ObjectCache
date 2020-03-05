program TwoLevelCache;

{$APPTYPE CONSOLE}
{$R *.res}

uses
  System.SysUtils,
  mCache in '..\src\mCache.pas',
  mObjectSerializer in '..\src\mObjectSerializer.pas',
  mObjectCache in '..\src\mObjectCache.pas',
  demoObject in 'demoObject.pas',
  demoObjectCache in 'demoObjectCache.pas',
  demoCache in 'demoCache.pas';

begin
{$IFDEF DEBUG}
  ReportMemoryLeaksOnShutdown := True;
{$ENDIF}
  try
    { cDemo1;
   Exit;      }
    writeln('Demo 1');
    Demo;
    writeln('Demo 2');
    Demo2;
    writeln('Demo 3');
    Demo3;
  except
    on E: Exception do
      writeln(E.ClassName, ': ', E.Message);
  end;
  ReadLn;

end.
