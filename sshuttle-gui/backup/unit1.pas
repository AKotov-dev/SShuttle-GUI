unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, Buttons,
  ComCtrls, ExtCtrls, Process, DefaultTranslator, IniFiles;

type

  { TMainForm }

  TMainForm = class(TForm)
    Image1: TImage;
    IPv6Box: TCheckBox;
    LatencyBox: TCheckBox;
    AutoStartBox: TCheckBox;
    PortEdit: TEdit;
    Label4: TLabel;
    UserEdit: TEdit;
    PasswordEdit: TEdit;
    ServerEdit: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Shape1: TShape;
    StartBtn: TSpeedButton;
    StaticText1: TStaticText;
    procedure AutoStartBoxChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure StartBtnClick(Sender: TObject);
    procedure StartProcess(command: string);
    procedure SaveSettings;
    procedure LoadSettings;
    procedure SaveConnection;

  private

  public

    SERVER_IP_PREV, SERVER_PORT_PREV, CONF: string;

  end;

var
  MainForm: TMainForm;
  FormLoaded: boolean;
  //Флаг загрузки формы от двойного срабатывания чекеров

resourcestring

  SStart = 'Start';
  SStop = 'Stop';

implementation

uses pingtrd;

  {$R *.lfm}

  { TMainForm }


//Сохранение настроек формы
procedure TMainForm.SaveSettings;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(CONF);
  try
    Ini.WriteInteger('TApplication.MainForm', 'MainForm_Top', MainForm.Top);
    Ini.WriteInteger('TApplication.MainForm', 'MainForm_Left', MainForm.Left);
    Ini.WriteInteger('TApplication.MainForm', 'MainForm_Width', MainForm.Width);
    Ini.WriteInteger('TApplication.MainForm', 'MainForm_Height', MainForm.Height);
  finally
    Ini.Free;
  end;
end;

//Загрузка настроек формы
procedure TMainForm.LoadSettings;
var
  Ini: TIniFile;
begin
  //  if not FileExists(CONF) then Exit;
  Ini := TIniFile.Create(CONF);
  try
    MainForm.Top := Ini.ReadInteger('TApplication.MainForm', 'MainForm_Top',
      MainForm.Top);
    MainForm.Left := Ini.ReadInteger('TApplication.MainForm',
      'MainForm_Left', MainForm.Left);
    MainForm.Width := Ini.ReadInteger('TApplication.MainForm',
      'MainForm_Width', MainForm.Width);
    MainForm.Height := Ini.ReadInteger('TApplication.MainForm',
      'MainForm_Height', MainForm.Height);

    //Данные соединения
    UserEdit.Text := Ini.ReadString('TApplication.MainForm', 'UserEdit_Text',
      UserEdit.Text);
    PasswordEdit.Text := Ini.ReadString('TApplication.MainForm',
      'PasswordEdit_text', PasswordEdit.Text);
    ServerEdit.Text := Ini.ReadString('TApplication.MainForm',
      'ServerEdit_Text', ServerEdit.Text);
    PortEdit.Text := Ini.ReadString('TApplication.MainForm', 'PortEdit_Text',
      PortEdit.Text);

    IPv6Box.Checked := Ini.ReadBool('TApplication.MainForm',
      'IPv6Box_Checked', IPv6Box.Checked);
    LatencyBox.Checked := Ini.ReadBool('TApplication.MainForm',
      'LatencyBox_Checked', LatencyBox.Checked);

  finally
    Ini.Free;
  end;
end;

//Сохранение данных соединения только по нажатию Start
procedure TMainForm.SaveConnection;
var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create(CONF);
  try
    //Данные соединения
    Ini.WriteString('TApplication.MainForm', 'UserEdit_Text', UserEdit.Text);
    Ini.WriteString('TApplication.MainForm', 'PasswordEdit_text', PasswordEdit.Text);

    Ini.WriteString('TApplication.MainForm', 'ServerEdit_Text', ServerEdit.Text);
    Ini.WriteString('TApplication.MainForm', 'PortEdit_Text', PortEdit.Text);

    Ini.WriteBool('TApplication.MainForm', 'IPv6Box_Checked', IPv6Box.Checked);
    Ini.WriteBool('TApplication.MainForm', 'LatencyBox_Checked', LatencyBox.Checked);

  finally
    Ini.Free;
  end;
end;

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
  bmp: TBitmap;
begin
  MainForm.Caption := Application.Title;

  //Устраняем баг иконки приложения
  bmp := TBitmap.Create;
  try
    bmp.PixelFormat := pf32bit;
    bmp.Assign(Image1.Picture.Graphic);
    Application.Icon.Assign(bmp);
  finally
    bmp.Free;
  end;

  //Каталог ключей и Рабочая директория (/root/.ssh/known_hosts создаётся автоматически)
  if not DirectoryExists('/root/.ssh') then MkDir('/root/.ssh');
  if not DirectoryExists('/etc/sshuttle-gui') then MkDir('/etc/sshuttle-gui');

  //Фвйл конфигурации
  CONF := '/etc/sshuttle-gui/settings.conf';

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

procedure TMainForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  SaveSettings;
end;

procedure TMainForm.FormShow(Sender: TObject);
var
  FCheckPingThread: TThread;
begin
  //Высота/Ширина формы (Auto)
 { MainForm.Height := LatencyBox.Top + LatencyBox.Height + StaticText1.Height + 6;
  MainForm.Width := StartBtn.Left + StartBtn.Height + 25;
  }

  LoadSettings;

  //Запоминаем предыдушие сервер:порт для очистки ~/.ssh/known_hosts
  SERVER_IP_PREV := ServerEdit.Text;
  SERVER_PORT_PREV := PortEdit.Text;

  AutostartBox.Checked := CheckAutoStart;

  //Поток проверки пинга
  FCheckPingThread := CheckPing.Create(False);
  FCheckPingThread.Priority := tpNormal;

  //Флаг загрузки формы от двойного срабатывания чекеров
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
  // IniPropStorage1.Save;

  SaveConnection;

  //Построение дополнительных параметров
  Pars := '';
  if IPv6Box.Checked then Pars := IPv6Box.Caption;
  if LatencyBox.Checked then Pars := Concat(Pars, ' ', LatencyBox.Caption);

  //Старт/Стоп VPN (ip(6)tables -L -t nat) - используется таблица ip(6)tables
  //Цепочки очищаются после останова: systemctl stop sshuttle + отмена зависших sshpass и очистка NAT
  if StartBtn.Caption = SStop then
  begin
    Shape1.Brush.Color := clYellow;
    StartProcess('systemctl stop sshuttle; pidof sshpass && killall sshpass');
    //iptables -t nat -F; ip6tables -t nat -F
  end
  else
  try
    //Содаём пускач для systemd (Type=simple)
    S := TStringList.Create;

    S.Add('#!/bin/bash');
    S.Add('');

    S.Add('# Пересоздать ключи в /root/.ssh/known_hosts (параметры подключения могли измениться)');

    //Очистка прежних ключей (мог измениться пароль или хост)
    //Если это не первый запуск
    if (SERVER_IP_PREV <> '') and (SERVER_PORT_PREV <> '') then
    begin
      //Очищаем старые ключи (переменные уже в памяти после загрузки формы)
      if SERVER_PORT_PREV = '22' then
        S.Add('ssh-keygen -R "' + SERVER_IP_PREV + '" 2>/dev/null')
      else
        S.Add('ssh-keygen -R "[' + SERVER_IP_PREV + ']:' + SERVER_PORT_PREV +
          '" 2>/dev/null');

      S.Add('');
    end;

    //Забираем публичные ключи с сервера
    S.Add('# Забираем публичные ключи с сервера');
    S.Add('pidof sshpass && killall sshpass');
    // ; iptables -t nat -F; ip6tables -t nat -F'
    S.Add('ssh-keyscan -q -p "' + PortEdit.Text + '" "' + ServerEDit.Text +
      '" >> /root/.ssh/known_hosts');

    S.Add('');

    S.Add('# Запуск vpn; exec ');
    S.Add('[[ "$?" -eq "0" ]] && \');
    S.Add('exec sshpass -p ''' + PasswordEdit.Text + ''' sshuttle --dns --remote ' +
      UserEdit.Text + '@' + ServerEDit.Text + ':' + PortEdit.Text +
      ' -x ' + ServerEDit.Text + ':' + PortEdit.Text + ' 0/0 ' + Trim(Pars));

    S.Add('');

  {  S.Add('# Принудительная очистка iptables nat');
    S.Add('iptables -t nat -F; ip6tables -t nat -F');

    S.Add('');}

    S.Add('exit 0');

    S.SaveToFile('/etc/sshuttle-gui/connect.sh');

    //Запоминаем новые данные переменных для последующей чистки
    SERVER_IP_PREV := ServerEdit.Text;
    SERVER_PORT_PREV := PortEdit.Text;

    //Запускаем скрипт через systemd
    StartProcess(
      'chmod 700 /etc/sshuttle-gui/connect.sh; chmod 600 /etc/sshuttle-gui/settings.conf; systemctl restart sshuttle');

  finally
    S.Free;
  end;
end;

end.
