unit start_trd;

{$mode objfpc}{$H+}

interface

uses
  Classes, Process, SysUtils, ComCtrls;

type
  StartConnect = class(TThread)
  private

    { Private declarations }
  protected
  var
    Result: TStringList;

    procedure Execute; override;

    procedure ShowLog;
    procedure StartProgress;
    procedure StopProgress;

  end;

implementation

uses Unit1;

{ TRD }

procedure StartConnect.Execute;
var
  ExProcess: TProcess;
begin
  try //Вывод лога
    Synchronize(@StartProgress);

    FreeOnTerminate := True; //Уничтожить по завершении
    Result := TStringList.Create;

    //Рабочий процесс
    ExProcess := TProcess.Create(nil);

    //Connect via ppp0
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add('chmod +x /etc/sshuttle-gui/connect.sh; bash ' +
      '/etc/sshuttle-gui/connect.sh');

    ExProcess.Options := [poUsePipes, poStderrToOutPut];

    ExProcess.Execute;

    //Выводим лог динамически
    while ExProcess.Running do
    begin
      Result.LoadFromStream(ExProcess.Output);

      //Выводим лог
      if Result.Count <> 0 then
        Synchronize(@ShowLog);
    end;

  finally
    Synchronize(@StopProgress);
    Result.Free;
    ExProcess.Free;
    Terminate;
  end;
end;

{ БЛОК ОТОБРАЖЕНИЯ ЛОГА }

//Старт скрипта подключения. Процесс активен до завершения sstpc.
procedure StartConnect.StartProgress;
begin
  with MainForm do
  begin
    LogMemo.Clear;
    StartBtn.Enabled := False;
    StartBtn.Refresh;
  end;
end;

//Стоп (возникает при обрыве или нажатии Stop)
procedure StartConnect.StopProgress;
begin
  with MainForm do
  begin
    if Trim(Result[0]) <> '---' then
      StartBtn.Enabled := True;
    StartBtn.Refresh;

    //Сохраняем историю
    IniPropStorage1.Save;
  end;
end;

//Вывод лога
procedure StartConnect.ShowLog;
var
  i: integer;
begin
  //Вывод построчно
  for i := 0 to Result.Count - 1 do
    MainForm.LogMemo.Lines.Append(Result[i]);

  //Промотать список вниз
  MainForm.LogMemo.SelStart := Length(MainForm.LogMemo.Text);
  MainForm.LogMemo.SelLength := 0;
end;

end.
