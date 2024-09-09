unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  ComCtrls, ExtCtrls, IniPropStorage, Process, DefaultTranslator;

type

  { TMainForm }

  TMainForm = class(TForm)
    IPv6Box: TCheckBox;
    LatencyBox: TCheckBox;
    ClearBox: TCheckBox;
    AutoStartBox: TCheckBox;
    PortEdit: TEdit;
    Label4: TLabel;
    UserEdit: TEdit;
    PasswordEdit: TEdit;
    ServerEdit: TEdit;
    IniPropStorage1: TIniPropStorage;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Shape1: TShape;
    StartBtn: TSpeedButton;
    StaticText1: TStaticText;
    procedure AutoStartBoxChange(Sender: TObject);
    procedure ClearBoxChange(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure StartProcess(command: string);

  private

  public

  end;

var
  MainForm: TMainForm;

resourcestring

  SStart = 'Start';
  SStop = 'Stop';

implementation

uses pingtrd;

  {$R *.lfm}

  { TMainForm }

//Общая процедура запуска команд (асинхронная)
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  Application.ProcessMessages;
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := '/bin/bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    //  ExProcess.Options := ExProcess.Options + [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Проверка чекбокса ClearBox (очистка кеш/cookies)
function CheckClear: boolean;
begin
  if FileExists('/etc/sshuttle-gui/clear') then
    Result := True
  else
    Result := False;
end;

//Проверка чекбокса AutoStart
function CheckAutoStart: boolean;
var
  S: ansistring;
begin
  RunCommand('/bin/bash', ['-c',
    '[[ -n $(systemctl is-enabled sshuttle | grep "enabled") ]] && echo "yes"'],
    S);

  if Trim(S) = 'yes' then
    Result := True
  else
    Result := False;
end;

procedure TMainForm.FormCreate(Sender: TObject);
var
  FCheckPingThread: TThread;
begin
  MainForm.Caption := Application.Title;

  //Каталог ключей и Рабочая директория
  if not DirectoryExists('/root/.ssh') then MkDir('/root/.ssh');
  if not DirectoryExists('/etc/sshuttle-gui') then MkDir('/etc/sshuttle-gui');

  IniPropStorage1.IniFileName := '/etc/sshuttle-gui/settings.conf';

  //Поток проверки пинга
  FCheckPingThread := CheckPing.Create(False);
  FCheckPingThread.Priority := tpNormal;
end;

procedure TMainForm.ClearBoxChange(Sender: TObject);
var
  S: ansistring;
begin
  if not ClearBox.Checked then
    RunCommand('/bin/bash', ['-c', 'rm -f /etc/sshuttle-gui/clear'], S)
  else
    RunCommand('/bin/bash', ['-c', 'touch /etc/sshuttle-gui/clear'], S);
end;

procedure TMainForm.AutoStartBoxChange(Sender: TObject);
var
  S: ansistring;
begin
  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;

  if not AutoStartBox.Checked then
    RunCommand('/bin/bash', ['-c', 'systemctl disable sshuttle.service'], S)
  else
    RunCommand('/bin/bash', ['-c', 'systemctl enable sshuttle.service'], S);
  Screen.Cursor := crDefault;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  //IniPropStorage1.Restore;

  //Высота/Ширина формы (Auto)
  MainForm.Height := ClearBox.Top + ClearBox.Height + StaticText1.Height + 5;
  MainForm.Width := StartBtn.Left + StartBtn.Height + 25;

  AutostartBox.Checked := CheckAutoStart;
  ClearBox.Checked := CheckClear;
end;

//Start VPN
procedure TMainForm.StartBtnClick(Sender: TObject);
var
  Pars: string;
  S: TStringList;
begin
  //Проверка на пустоту
  if (Trim(UserEdit.Text) = '') or (Trim(PasswordEdit.Text) = '') or
    (Trim(ServerEdit.Text) = '') or (Trim(PortEdit.Text) = '') then Exit;

  IniPropStorage1.Save;

  //Дополнительные параметры
  Pars := '';
  if IPv6Box.Checked then Pars := IPv6Box.Caption;
  if LatencyBox.Checked then Pars := Concat(Pars, ' ', LatencyBox.Caption);

  //Старт/Стоп VPN (ip(6)tables -L -t nat) - используется таблица ip(6)tables
  //Цепочки очищаются после останова: systemctl stop sshuttle
  if StartBtn.Caption = SStop then
  begin
    Shape1.Brush.Color := clYellow;
    StartProcess('systemctl stop sshuttle.service');
  end
  else
  try
    S := TStringList.Create;

    S.Add('#!/bin/bash');
    S.Add('');

    //Содаём пускач для systemd (Type=simple)
    S.Add('# Пересоздание ключей в /root/.ssh/known_hosts (пароль мог изменяться)');

    //Очистка прежних ключей (мог измениться пароль или хост)
    S.Add('sed -i "/^' + Trim(ServerEDit.Text) + '/d" /root/.ssh/known_hosts');

   { S.Add('if [[ -z $(ssh-keygen -F ' +  Trim(ServerEDit.Text) + ') ]]; then'); }

    //Пересоздать ключи для хоста (пароль мог измениться) + отмена зависших sshpass
    S.Add('killall sshpass; sshpass -p "' + Trim(PasswordEdit.Text) +
      '" ssh -o StrictHostKeyChecking=No ' + Trim(UserEdit.Text) +
      // '@' + Trim(ServerEDit.Text) + ' -p ' + Trim(PortEdit.Text) + ' exit 0; fi');
      '@' + Trim(ServerEDit.Text) + ' -p ' + Trim(PortEdit.Text));

    S.Add('');

    S.Add('# Запуск vpn');
    S.Add('[[ "$?" -eq "0" ]] && \');
    S.Add('sshpass -p "' + Trim(PasswordEdit.Text) + '" sshuttle --dns --remote ' +
      Trim(UserEdit.Text) + '@' + Trim(ServerEDit.Text) + ':' +
      Trim(PortEdit.Text) + ' -x ' + Trim(ServerEDit.Text) + ':' +
      Trim(PortEdit.Text) + ' 0/0 ' + Trim(Pars));

    S.Add('exit 0');

    S.SaveToFile('/etc/sshuttle-gui/connect.sh');

    //Запускаем скрипт через systemd
    StartProcess('chmod +x /etc/sshuttle-gui/connect.sh; systemctl restart sshuttle.service');

  finally
    S.Free;
  end;
end;


end.
