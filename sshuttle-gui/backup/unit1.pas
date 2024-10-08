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
  FormLoaded: boolean;

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

  //Каталог ключей и Рабочая директория (/root/.ssh/known_hosts создаётся автоматически)
  if not DirectoryExists('/root/.ssh') then MkDir('/root/.ssh');
  if not DirectoryExists('/etc/sshuttle-gui') then MkDir('/etc/sshuttle-gui');

  IniPropStorage1.IniFileName := '/etc/sshuttle-gui/settings.conf';
end;

//Флаг очистки кеша браузеров при старте GUI
procedure TMainForm.ClearBoxChange(Sender: TObject);
var
  S: ansistring;
begin
  if not FormLoaded then Exit;

  if not ClearBox.Checked then
    RunCommand('/bin/bash', ['-c', 'rm -f /etc/sshuttle-gui/clear'], S)
  else
    RunCommand('/bin/bash', ['-c', 'touch /etc/sshuttle-gui/clear'], S);
end;

//Автостарт SShuttle после загрузки
procedure TMainForm.AutoStartBoxChange(Sender: TObject);
var
  S: ansistring;
begin
  if not FormLoaded then Exit;

  Screen.Cursor := crHourGlass;
  Application.ProcessMessages;

  if not AutoStartBox.Checked then
    RunCommand('/bin/bash', ['-c', 'systemctl disable sshuttle'], S)
  else
    RunCommand('/bin/bash', ['-c', 'systemctl enable sshuttle'], S);
  Screen.Cursor := crDefault;
end;

procedure TMainForm.FormShow(Sender: TObject);
begin
  //Высота/Ширина формы (Auto)
  MainForm.Height := ClearBox.Top + ClearBox.Height + StaticText1.Height + 6;
  MainForm.Width := StartBtn.Left + StartBtn.Height + 25;

  AutostartBox.Checked := CheckAutoStart;
  ClearBox.Checked := CheckClear;

  //Поток проверки пинга
  FCheckPingThread := CheckPing.Create(False);
  FCheckPingThread.Priority := tpNormal;

  FormLoaded := True;
end;

//Start VPN
procedure TMainForm.StartBtnClick(Sender: TObject);
var
  Pars: string;
  S: TStringList;
begin
  //Форматируем содержимое полей
  UserEdit.Text := Trim(UserEdit.Text);
  PasswordEdit.Text := Trim(PasswordEdit.Text);
  ServerEdit.Text := Trim(ServerEdit.Text);
  PortEdit.Text := Trim(PortEdit.Text);

  //Проверка на пустоту
  if (UserEdit.Text = '') or (PasswordEdit.Text = '') or
    (ServerEdit.Text = '') or (PortEdit.Text = '') then Exit;

  //Сохраняем параметры
  IniPropStorage1.Save;

  //Построение дополнительных параметров
  Pars := '';
  if IPv6Box.Checked then Pars := IPv6Box.Caption;
  if LatencyBox.Checked then Pars := Concat(Pars, ' ', LatencyBox.Caption);

  //Старт/Стоп VPN (ip(6)tables -L -t nat) - используется таблица ip(6)tables
  //Цепочки очищаются после останова: systemctl stop sshuttle + отмена зависших sshpass и очистка NAT
  if StartBtn.Caption = SStop then
  begin
    Shape1.Brush.Color := clYellow;
    StartProcess('systemctl stop sshuttle; pidof sshpass && killall sshpass; iptables -t nat -F');
  end
  else
  try
    //Содаём пускач для systemd (Type=simple)
    S := TStringList.Create;

    S.Add('#!/bin/bash');
    S.Add('');

    S.Add('# Пересоздать ключи в /root/.ssh/known_hosts (параметры подключения могли измениться)');

    //Очистка прежних ключей (мог измениться пароль или хост)
    S.Add('sed -i "/^' + ServerEDit.Text + '/d" /root/.ssh/known_hosts');
    S.Add('');

    //Пересоздать ключи для хоста (пароль мог измениться) + отмена зависших sshpass и очистка NAT
   { S.Add('pidof sshpass && killall sshpass; iptables -t nat -F; sshpass -p "' +
      Trim(PasswordEdit.Text) + '" ssh -o StrictHostKeyChecking=No ' +
      Trim(UserEdit.Text) + '@' + Trim(ServerEDit.Text) + ' -p ' +
      Trim(PortEdit.Text) + ' exit 0'); }

    //Забираем публичные ключи с сервера
    S.Add('# Забираем публичные ключи с сервера');
    S.Add('pidof sshpass && killall sshpass; iptables -t nat -F');
    S.Add('ssh-keyscan -p ' + PortEdit.Text + ' ' + ServerEDit.Text +
      ' >> /root/.ssh/known_hosts');

    S.Add('');

    S.Add('# Запуск vpn');
    S.Add('[[ "$?" -eq "0" ]] && \');
    S.Add('sshpass -p "' + PasswordEdit.Text + '" sshuttle --dns --remote ' +
      UserEdit.Text + '@' + ServerEDit.Text + ':' + PortEdit.Text +
      ' -x ' + ServerEDit.Text + ':' + PortEdit.Text + ' 0/0 ' + Trim(Pars));

    S.Add('');

    S.Add('# Принудительная очистка iptables nat');
    S.Add('iptables -t nat -F');

    S.Add('exit 0;');

    S.SaveToFile('/etc/sshuttle-gui/connect.sh');

    //Запускаем скрипт через systemd
    StartProcess('chmod +x /etc/sshuttle-gui/connect.sh; systemctl restart sshuttle');

  finally
    S.Free;
  end;
end;

end.
