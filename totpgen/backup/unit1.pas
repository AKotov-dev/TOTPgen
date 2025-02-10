unit Unit1;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, Buttons, StdCtrls,
  IniPropStorage, DefaultTranslator, LCLTranslator, LCLType, ClipBrd,
  AsyncProcess, Types, FileUtil, Process, IniFiles, LCLIntf, ExtCtrls,
  URIParser;

type

  { TMainForm }

  TMainForm = class(TForm)
    AddBtn: TSpeedButton;
    GetQR: TAsyncProcess;
    Image1: TImage;
    ImageList2: TImageList;
    QRBtn: TSpeedButton;
    GETBtn: TBitBtn;
    DeleteBtn: TSpeedButton;
    EditBtn: TSpeedButton;
    GetTOTP: TAsyncProcess;
    ImageList1: TImageList;
    IniPropStorage1: TIniPropStorage;
    ListBox1: TListBox;
    LoadBtn: TSpeedButton;
    OpenDialog1: TOpenDialog;
    SaveBtn: TSpeedButton;
    SaveDialog1: TSaveDialog;
    SelectAll: TSpeedButton;
    SortBtn: TSpeedButton;
    StaticText1: TStaticText;
    procedure AddBtnClick(Sender: TObject);
    procedure DeleteBtnClick(Sender: TObject);
    procedure EditBtnClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
    procedure FormShow(Sender: TObject);
    procedure GETBtnClick(Sender: TObject);
    procedure GetQRReadData(Sender: TObject);
    procedure GetTOTPReadData(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure ListBox1DblClick(Sender: TObject);
    procedure ListBox1DrawItem(Control: TWinControl; Index: integer;
      ARect: TRect; State: TOwnerDrawState);
    procedure ListBox1KeyPress(Sender: TObject; var Key: char);
    procedure LoadBtnClick(Sender: TObject);
    procedure QRBtnClick(Sender: TObject);
    procedure SaveBtnClick(Sender: TObject);
    procedure SelectAllClick(Sender: TObject);
    procedure SortBtnClick(Sender: TObject);
    procedure StartProcess(command: string);
    function QRDecode(URL, val: string): string;
    //   function URLDecode(URL, val: string): string;

  private

  public

  end;

  //Ресурсы перевода
resourcestring
  SAppRunning = 'The program is already running!';
  SDeleteConfiguration = 'Remove selected from list?';
  SAppendRecord = 'Append entry';
  SEditRecord = 'Editing entry';
  SRecordExists = 'The record already exists!';
  SNoKeyFormat = 'The key format is not defined!';
  SNoBackup = 'The archive does not correspond to TOTPgen!';

var
  MainForm: TMainForm;
  WorkDir: string;

implementation

uses totp_unit, data_unit;

  {$R *.lfm}

  { TMainForm }

//Парсер URL otpauth://totp/%...
//URL - Декодирование/Нормализация/Поиск
function TMainForm.QRDecode(URL, val: string): string;
var
  U: TURI;
  i: integer;
  S: TStringList;
begin
  try
    Result := 'none';
    S := TStringList.Create;

    //Нормализация URL; Убираем переводы строк
    URL := StringReplace(URL, #13#10, '', [rfReplaceAll, rfIgnoreCase]);
    //Убираем пробелы
    URL := StringReplace(URL, ' ', '', [rfReplaceAll, rfIgnoreCase]);
    //Убираем кавычки
    URL := StringReplace(URL, '"', '', [rfReplaceAll, rfIgnoreCase]);

    //Декодируем и парсим URL (stage-1)
    U := URIParser.ParseURI(URL, True);

    //LABEL
    case val of
      'label': Result := U.Document;
    end;

    //Если не найден выше...
    if (Result = 'none') and (U.Params <> '') then
    begin
      //Stage-2; Остальные параметры: security, type, encryption, path

      //Грузим линейный текст
      S.Text := U.Params;

      //Разделяем значения на Items по (&)
      S.Delimiter := '&';
      S.StrictDelimiter := True;
      S.DelimitedText := S[0];

      //Поиск соответствия
      for i := 0 to S.Count - 1 do
        if Copy(S[i], 1, Pos('=', S[i]) - 1) = val then
        begin
          Result := Copy(S[i], Pos('=', S[i]) + 1, Length(S[i]));
          Break;
        end;
    end;

  finally
    S.Free;
  end;
end;

//Валидация загружаемого архива (БД из *.tar.gz)
function IsBackup(input: string): boolean;
var
  ExProcess: TProcess;
  S: TStringList;
begin
  Result := True;
  S := TStringList.Create;
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add('tar -ztf "' + input + '" | grep "./totp.list"');
    ExProcess.Options := [poWaitOnExit, poUsePipes];
    ExProcess.Execute;
    S.LoadFromStream(ExProcess.Output);

    if S.Count = 0 then Result := False;
  finally
    S.Free;
    ExProcess.Free;
  end;
end;

//HEX или Base32
function IsHexOrBase32(const str: string): string;
var
  i: integer;
  isHex, isBase32: boolean;
begin
  isHex := True;
  isBase32 := True;

  // Проверяем, является ли строка корректным hex
  for i := 1 to Length(str) do
  begin
    if not (str[i] in ['0'..'9', 'a'..'f', 'A'..'F']) then
    begin
      isHex := False;
      Break;
    end;
  end;

  // Проверяем, является ли строка корректным base32
  for i := 1 to Length(str) do
  begin
    if not (str[i] in ['A'..'Z', '2'..'7', '=', 'a'..'z']) then
    begin
      isBase32 := False;
      Break;
    end;
  end;

  // Возвращаем результат
  if isHex then
    Result := ' '
  else if isBase32 then
    Result := ' -b '
  else
    Result := 'Unknown';
end;

//StartCommand
procedure TMainForm.StartProcess(command: string);
var
  ExProcess: TProcess;
begin
  ExProcess := TProcess.Create(nil);
  try
    ExProcess.Executable := 'bash';
    ExProcess.Parameters.Add('-c');
    ExProcess.Parameters.Add(command);
    ExProcess.Options := [poWaitOnExit];
    ExProcess.Execute;
  finally
    ExProcess.Free;
  end;
end;

//Рабочий каталог WorkDir
procedure TMainForm.FormCreate(Sender: TObject);
begin
  MainForm.Caption := Application.Title;

  if not DirectoryExists(GetUserDir + '.config/totpgen') then
    MkDir(GetUserDir + '.config/totpgen');

  WorkDir := GetUserDir + '.config/totpgen/';

  IniPropStorage1.IniFileName := WorkDir + 'totpgen.conf';
end;

//Опрос клавиш
procedure TMainForm.FormKeyUp(Sender: TObject; var Key: word; Shift: TShiftState);
begin
  case Key of
    VK_F4: EditBtn.Click;
    VK_F8: DeleteBtn.Click;
    VK_INSERT: AddBtn.Click;
  end;

  //Отлуп после закрытия модального окна
  Key := $0;
end;

//Инициализация
procedure TMainForm.FormShow(Sender: TObject);
begin
  IniPropStorage1.Restore; //Для Plasma

  if FileExists(WorkDir + 'totp.list') then
  begin
    ListBox1.Items.LoadFromFile(WorkDir + 'totp.list');
    if ListBox1.Count <> 0 then
      ListBox1.ItemIndex := 0;
  end
  else
    ListBox1.Items.SaveToFile(WorkDir + 'totp.list');

  if ListBox1.Count <> 0 then ListBox1.Click;
end;

//Online QR Generator: https://stefansundin.github.io/2fa-qr/
//Doc: https://www.tenminutetutor.com/data-formats/binary-encoding/base32-encoding/
//A..Z a..z 2..7  max field length = 40 symbols
procedure TMainForm.GETBtnClick(Sender: TObject);
var
  INI: TIniFile;
  KEY, HASH: string;
  DIGITS, COUNTER, HOTP: integer;
begin
  if ListBox1.SelCount = 0 then Exit;

  try
    INI := TIniFile.Create(WorkDir + ListBox1.Items[ListBox1.ItemIndex]);
    KEY := INI.ReadString('TApplication.DataForm', 'Edit2_Text', '');
    HASH := INI.ReadString('TApplication.DataForm', 'Combobox1_Text', 'SHA1');
    DIGITS := INI.ReadInteger('TApplication.DataForm', 'SpinEdit1_Value', 6);
    COUNTER := INI.ReadInteger('TApplication.DataForm', 'HOTPCounter_Value', 0);
    HOTP := INI.ReadInteger('TApplication.DataForm', 'HOTP_Checked', 0);

    GetTOTP.Parameters.Clear;
    GetTOTP.Parameters.Add('-c');

    if IsHexOrBase32(KEY) <> 'Unknown' then
    begin
      if HOTP = 0 then
        //Валидация символов TOTP: HEX или BASE32
        GetTOTP.Parameters.Add('oathtool' + IsHexOrBase32(KEY) +
          '--totp=' + HASH + ' --digits=' + IntToStr(DIGITS) + ' ' + '''' + KEY + '''')
      else
        //HOTP
        GetTOTP.Parameters.Add('oathtool' + IsHexOrBase32(KEY) +
          '--hotp --digits=' + IntToStr(DIGITS) + ' ' + '''' + KEY +
          '''' + ' --counter=' + IntToStr(COUNTER));

      //Получить TOTP
      GetTOTP.Execute;
    end
    else
      //Формат ключа не определен
      MessageDlg(SNoKeyFormat, mtWarning, [mbOK], 0);

  finally
    INI.Free;
  end;
end;

//Форма новой записи списка (добавление)
procedure TMainForm.GetQRReadData(Sender: TObject);
var
  S: TStringList;
begin
  try
    S := TStringList.Create;
    S.LoadFromStream(GetQR.Output);

    //Если код 'otpauth://totp' существует
    if (S.Count <> 0) and ((Pos('otpauth://totp', S[0]) <> 0) or
      (Pos('otpauth://hotp', S[0]) <> 0)) then
      //Default add
      with DataForm do
      begin
        TOTPini.IniFileName := '';

        Caption := SAppendRecord;
        Edit1.Clear;
        Edit2.Clear;
        ComboBox1.Text := 'SHA1';
        SpinEdit1.Value := 6;
        HOTP.Checked := False;
        HOTPCounter.Value := 0;

        S[0] := Trim(S[0]);

        //Дешифрация основных параметров из QR-кода
        //https://github.com/google/google-authenticator/wiki/Key-Uri-Format (Issuer - для новых версий)
        //https://docs.yubico.com/yesdk/users-manual/application-oath/uri-string-format.html

        if (QRDecode(S[0], 'label') <> '') then
          Edit1.Text := QRDecode(S[0], 'label')
        else
        if (QRDecode(S[0], 'issuer') <> 'none') then
          Edit1.Text := QRDecode(S[0], 'issuer');

        if (QRDecode(S[0], 'secret') <> 'none') then
          Edit2.Text := QRDecode(S[0], 'secret');

        if QRDecode(S[0], 'algorithm') <> 'none' then
          ComboBox1.Text := QRDecode(S[0], 'algorithm');

        if QRDecode(S[0], 'digits') <> 'none' then
          SpinEdit1.Value := StrToInt(QRDecode(S[0], 'digits'));

        if QRDecode(S[0], 'counter') <> 'none' then
        begin
          HOTP.Checked := True;
          HOTPCounter.Value := StrToInt(QRDecode(S[0], 'counter'));
        end;

        ShowModal;
      end;
  finally
    S.Free;
  end;
end;

//Вывод TOTP
procedure TMainForm.GetTOTPReadData(Sender: TObject);
var
  S: TStringList;
begin
  try
    S := TStringList.Create;
    S.LoadFromStream(GetTOTP.Output);

    if Pos(':', S.Text) <> 0 then
      //Формат ключа не определен
      MessageDlg(SNoKeyFormat, mtWarning, [mbOK], 0)
    else
    begin //Иначе - копируем в буфер и выводим код TOTP/HOTP
      ClipBoard.AsText := Trim(S[0]);
      TOTPForm.Label1.Caption := Trim(S[0]);

      TOTPForm.ShowModal;
    end;
  finally
    S.Free;
  end;
end;

// URLEncode
function URLEncode(const S: string): string;
const
  HexChars: array[0..15] of char = '0123456789ABCDEF';
var
  I: integer;
  C: char;
begin
  Result := '';
  for I := 1 to Length(S) do
  begin
    C := S[I];
    if (C in ['a'..'z', 'A'..'Z', '0'..'9', '-', '.', '_', '~']) then
      Result := Result + C
    else
      Result := Result + '%' + HexChars[Ord(C) shr 4] + HexChars[Ord(C) and $0F];
  end;
end;

//URLDecode
function URLDecode(const S: string): string;
var
  I, Len: integer;
  HexStr: string;
  DecodedChar: char;
begin
  Result := '';
  Len := Length(S);
  I := 1;

  while I <= Len do
  begin
    if (S[I] = '%') and (I + 2 <= Len) then
    begin
      // Получаем 2 символа после '%', чтобы декодировать их как шестнадцатеричное число
      HexStr := Copy(S, I + 1, 2);
      try
        // Преобразуем строку в число
        DecodedChar := Chr(StrToInt('$' + HexStr));
        Result := Result + DecodedChar;
        Inc(I, 3); // Пропускаем '%XX'
      except
        on E: EConvertError do
        begin
          // Если не удалось декодировать, просто добавляем '%' как есть
          Result := Result + '%';
          Inc(I);
        end;
      end;
    end
    else
    begin
      // Просто добавляем обычные символы
      Result := Result + S[I];
      Inc(I);
    end;
  end;
end;

//Отображение QR-кода из списка
procedure TMainForm.ListBox1Click(Sender: TObject);
var
  INI: TIniFile;
  QRtxt, KEY, HASH: string;
  DIGITS, COUNTER, HOTP: integer;
begin
  if ListBox1.Count = 0 then Exit;

  try
    INI := TIniFile.Create(WorkDir + ListBox1.Items[ListBox1.ItemIndex]);
    KEY := INI.ReadString('TApplication.DataForm', 'Edit2_Text', '');
    HASH := INI.ReadString('TApplication.DataForm', 'Combobox1_Text', 'SHA1');
    DIGITS := INI.ReadInteger('TApplication.DataForm', 'SpinEdit1_Value', 6);
    COUNTER := INI.ReadInteger('TApplication.DataForm', 'HOTPCounter_Value', 0);
    HOTP := INI.ReadInteger('TApplication.DataForm', 'HOTP_Checked', 0);

    if HOTP = 0 then
    begin
      QRtxt := QRtxt + 'otpauth://totp/';
      QRtxt := QRtxt + URLEncode(ListBox1.Items[ListBox1.ItemIndex]);
      QRtxt := QRtxt + '?';
      QRtxt := QRtxt + 'secret=' + KEY + '&' + 'issuer=' +
        URLEncode(ListBox1.Items[ListBox1.ItemIndex]) + '&' +
        'algorithm=' + HASH + '&' + 'digits=' + IntToStr(DIGITS);
    end
    else
    begin
      QRtxt := QRtxt + 'otpauth://hotp/';
      QRtxt := QRtxt + URLEncode(ListBox1.Items[ListBox1.ItemIndex]);
      QRtxt := QRtxt + '?';
      QRtxt := QRtxt + 'secret=' + KEY + '&' + 'issuer=' +
        URLEncode(ListBox1.Items[ListBox1.ItemIndex]) + '&' +
        'algorithm=' + HASH + '&' + 'digits=' + IntToStr(DIGITS) +
        '&' + 'counter=' + IntToStr(COUNTER);
    end;

    StartProcess('qrencode "' + QRtxt +
      '" -o ~/.config/totpgen/qr.xpm --margin=2 --type=XPM');

    if FileExists(GetUserDir + '.config/totpgen/qr.xpm') then
    begin
      Image1.Picture.LoadFromFile(GetUserDir + '.config/totpgen/qr.xpm');
      DeleteFile(GetUserDir + '.config/totpgen/qr.xpm');
    end;

    Image1.Visible := True;

  finally
    INI.Free;
  end;
end;

//Редактирование DblClick (F4)
procedure TMainForm.ListBox1DblClick(Sender: TObject);
begin
  if ListBox1.SelCount <> 0 then EditBtn.Click;
end;

//Иконки списка
procedure TMainForm.ListBox1DrawItem(Control: TWinControl; Index: integer;
  ARect: TRect; State: TOwnerDrawState);
var
  BitMap: TBitMap;
begin
  try
    BitMap := TBitMap.Create;
    with ListBox1 do
    begin
      Canvas.FillRect(aRect);

      //Название (текст по центру-вертикали)
      Canvas.TextOut(aRect.Left + 30, aRect.Top + ItemHeight div 2 -
        Canvas.TextHeight('A') div 2 + 1, Items[Index]);

      //Иконка
      ImageList1.GetBitMap(0, BitMap);

      Canvas.Draw(aRect.Left + 2, aRect.Top + (ItemHeight - 24) div 2 + 2, BitMap);
    end;
  finally
    BitMap.Free;
  end;
end;

procedure TMainForm.ListBox1KeyPress(Sender: TObject; var Key: char);
begin
  Key := #0;
end;

//Сохранить
procedure TMainForm.SaveBtnClick(Sender: TObject);
var
  ext: string;
begin
  ext := '';

  if SaveDialog1.Execute then
  begin
    Application.ProcessMessages;

    if ExtractFileExt(SaveDialog1.FileName) = '' then ext := '.tar.gz';

    StartProcess('cd ' + WorkDir + '; tar czf "' + SaveDialog1.FileName +
      ext + '" ./*');
  end;
end;

//Загрузить
procedure TMainForm.LoadBtnClick(Sender: TObject);
begin
  if OpenDialog1.Execute then
  begin
    //Проверка валидности загружаемого архива *.tar.gz
    Application.ProcessMessages;
    if not IsBackup(OpenDialog1.FileName) then
    begin
      MessageDlg(SNoBackup, mtWarning, [mbOK], 0);
      Exit;
    end;

    Application.ProcessMessages;

    StartProcess('cd ' + WorkDir + '; rm -f ./*; tar xzf "' +
      OpenDialog1.FileName + '"');

    if FileExists(WorkDir + 'totp.list') then
      ListBox1.Items.LoadFromFile(WorkDir + 'totp.list');

    if ListBox1.Count <> 0 then
    begin
      ListBox1.ItemIndex := 0;
      ListBox1.Click;
    end;
  end;
end;

//Снять скриншот и расшифровать QR (если найден); Test: https://stefansundin.github.io/2fa-qr/
procedure TMainForm.QRBtnClick(Sender: TObject);
var
  ScreenDC: HDC;
  MyBitmap: TBitmap;
begin
  try
    QRBtn.Enabled := False;

    //Скрываем уже показанный QR-код, поскольку будем искать новый на том же экране
    if Image1.Picture <> nil then
      ClipBoard.Assign(Image1.Picture);
    ImageList2.GetBitMap(0, Image1.Picture.Bitmap);

    Application.ProcessMessages;
    Sleep(300);
    Application.ProcessMessages;

    MyBitmap := TBitmap.Create;
    ScreenDC := GetDC(0);
    MyBitmap.LoadFromDevice(ScreenDC);
    MyBitmap.SaveToFile(WorkDir + 'screen.png');

    GetQR.Parameters.Clear;
    GetQR.Parameters.Add('-c');
    GetQR.Parameters.Add('zbarimg ' + WorkDir + 'screen.png > ' +
      WorkDir + 'code.txt; cat ' + WorkDir +
      'code.txt | grep QR-Code | cut -c 9-; rm -f ' + WorkDir + '{screen.png,code.txt}');

    GetQR.Execute;

    Image1.Picture.Assign(Clipboard);

  finally
    MyBitmap.Free;
    ClipBoard.Clear;
    QRBtn.Enabled := True;
  end;
end;

//Выбрать все
procedure TMainForm.SelectAllClick(Sender: TObject);
begin
  ListBox1.SelectAll;
end;

//Сортировать список
procedure TMainForm.SortBtnClick(Sender: TObject);
begin
  if ListBox1.Count <> 0 then
    with ListBox1 do
    begin
      Sorted := True;
      Items.SaveToFile(WorkDir + 'totp.list');
      Items.LoadFromFile(WorkDir + 'totp.list');
      Sorted := False;
      ItemIndex := 0;
      Click;
    end;
end;

//Удаление записи
procedure TMainForm.DeleteBtnClick(Sender: TObject);
var
  i: integer;
begin
  if ListBox1.SelCount <> 0 then
    if MessageDlg(SDeleteConfiguration, mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      //Удаление записей
      for i := -1 + ListBox1.Items.Count downto 0 do
        if ListBox1.Selected[i] then
        begin
          DeleteFile(WorkDir + ListBox1.Items[i]);
          ListBox1.Items.Delete(i);
        end;

      //Курсор в начало
      if ListBox1.Count <> 0 then
      begin
        ListBox1.ItemIndex := 0;
        ListBox1.Click;
      end
      else
        Image1.Hide;

      ListBox1.Items.SaveToFile(WorkDir + 'totp.list');
    end;
end;

//Редактирование записи
procedure TMainForm.EditBtnClick(Sender: TObject);
begin
  if ListBox1.SelCount = 0 then Exit;

  if (FileExists(WorkDir + ListBox1.items[ListBox1.ItemIndex])) and
    (ListBox1.SelCount = 1) then
  begin
    DataForm.Caption := SEditRecord;
    DataForm.TOTPini.IniFileName :=
      WorkDir + ListBox1.items[ListBox1.ItemIndex];
    DataForm.TOTPini.Restore;

    DataForm.Edit1.Text := ListBox1.Items[ListBox1.ItemIndex];
  end;

  DataForm.ShowModal;
end;

//Добавить запись
procedure TMainForm.AddBtnClick(Sender: TObject);
begin
  //Default add
  with DataForm do
  begin
    TOTPini.IniFileName := '';

    Caption := SAppendRecord;
    Edit1.Clear;
    Edit2.Clear;
    ComboBox1.Text := 'SHA1';
    SpinEdit1.Value := 6;
    HOTP.Checked := False;
    HOTPCounter.Value := 0;

    ShowModal;
  end;
end;

end.
