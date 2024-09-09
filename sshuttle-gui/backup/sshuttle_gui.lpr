program sshuttle_gui;

{$mode objfpc}{$H+}

uses
 {$IFDEF UNIX}
  cthreads,
    {$ENDIF} {$IFDEF HASAMIGA}
  athreads,
    {$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms,
  Unit1,
  PingTRD { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Title:='SShuttle-GUI v0.3';
  Application.Scaled:=True;
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
