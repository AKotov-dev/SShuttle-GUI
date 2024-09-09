unit PingTRD;

{$mode objfpc}{$H+}

interface

uses
  Classes, Forms, Controls, SysUtils, Process, Graphics;

type
  CheckPing = class(TThread)
  private

    { Private declarations }
  protected
  var
    PingStr: TStringList;

    procedure Execute; override;
    procedure ShowStatus;

  end;

implementation

uses unit1;

{ TRD }

procedure CheckPing.Execute;
var
  PingProcess: TProcess;
begin
  try
    FreeOnTerminate := True; //Уничтожать по завершении
    PingStr := TStringList.Create;

    PingProcess := TProcess.Create(nil);
    PingProcess.Executable := 'bash';

    while not Terminated do
    begin
      PingProcess.Parameters.Clear;
      PingProcess.Parameters.Add('-c');
      PingProcess.Parameters.Add(
        '[[ $(fping google.com) && $(systemctl is-active sshuttle) == "active" ]] && echo "yes" || echo "no"');

      PingProcess.Options := [poUsePipes, poWaitOnExit];

      PingProcess.Execute;
      PingStr.LoadFromStream(PingProcess.Output);
      Synchronize(@ShowStatus);

      Sleep(500);
    end;

  finally
    PingStr.Free;
    PingProcess.Free;
    Terminate;
  end;
end;

//Индикация: Cветодиод, Режим
procedure CheckPing.ShowStatus;
begin
  with MainForm do
  begin
    if Trim(PingStr[0]) = 'yes' then
    begin
      StartBtn.Caption := SStop;
      Shape1.Brush.Color := clLime;
    end
    else
    begin
      StartBtn.Caption := SStart;
      Shape1.Brush.Color := clYellow;
      end;

    Shape1.Repaint;
    StartBtn.Repaint;
  end;
end;

end.
