unit data_unit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, IniPropStorage,
  StdCtrls, Spin, Buttons;

type

  { TDataForm }

  TDataForm = class(TForm)
    ApplyBtn: TBitBtn;
    Edit3: TEdit;
    HOTP: TCheckBox;
    ComboBox1: TComboBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    SpinEdit1: TSpinEdit;
    HOTPCounter: TSpinEdit;
    TOTPini: TIniPropStorage;
    procedure ApplyBtnClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormShow(Sender: TObject);
    procedure HOTPChange(Sender: TObject);
  private

  public

  end;

var
  DataForm: TDataForm;

implementation

uses unit1;

  {$R *.lfm}

  { TDataForm }

//Независимый от регистра поиск в ListBox (IndexOf) на предмет совпадений
function IndexOfCaseSensitive(ListBox: TListBox; const Value: string): integer;
var
  i: integer;
begin
  Result := -1;
  for i := 0 to ListBox.Items.Count - 1 do
  begin
    if ListBox.Items[i] = Value then
    begin
      Result := i;
      Break;
    end;
  end;
end;

//Применить (Apply)
procedure TDataForm.ApplyBtnClick(Sender: TObject);
begin
  //Убираем возможные пробелы в значении секретного ключа (например из Яндекс)
  Edit2.Text := StringReplace(Edit2.Text, ' ', '', [rfReplaceAll, rfIgnoreCase]);

  //Если Имя или Ключ не введены = Выход
  if (Edit1.Text = '') or (Edit2.Text = '') or (Edit3.Text = '') then Exit;

  //Редактирование записи
  if (MainForm.ListBox1.SelCount <> 0) and (TOTPini.IniFileName <> '') then
  begin
    // ShowMessage('EDIT');
    TOTPini.Save;

    //Переименовать ini файл
    RenameFile(WorkDir + MainForm.ListBox1.items[MainForm.ListBox1.ItemIndex],
      WorkDir + Edit1.Text);

    MainForm.ListBox1.Items[MainForm.ListBox1.ItemIndex] := Edit1.Text;
    MainForm.ListBox1.Items.SaveToFile(WorkDir + 'totp.list');
  end
  else
  //Добавление записи
  if IndexOfCaseSensitive(MainForm.ListBox1, Edit1.Text) = -1 then
  begin
    //  ShowMessage('ADD');
    TOTPini.IniFileName := WorkDir + Edit1.Text;
    TOTPini.Save;

    MainForm.ListBox1.Items.Append(Trim(Edit1.Text));
    MainForm.ListBox1.Items.SaveToFile(WorkDir + 'totp.list');
    MainForm.ListBox1.ItemIndex := MainForm.ListBox1.Count - 1;
  end
  else
  begin
    MessageDlg(SRecordExists, mtInformation, [mbOK], 0);
    Exit;
  end;
  TOTPini.IniFileName := '';

  DataForm.Close;

  //Перечитать QR-картинку
  MainForm.ListBox1.SetFocus;
  MainForm.ListBox1.Click;
end;

//При новом открытии формы должны быть пусты
procedure TDataForm.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  Edit1.Clear;
  Edit2.Clear;
  Edit3.Clear;
  HOTP.Checked := False;
  HOTPCounter.Value := 0;
end;

//Нужно от дубликатов записей
procedure TDataForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  TOTPini.IniFileName := '';
end;

//Enter & Escape
procedure TDataForm.FormKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then ApplyBtn.Click;
  if Key = #27 then DataForm.Close;
end;

//Position
procedure TDataForm.FormShow(Sender: TObject);
begin
  Top := MainForm.Top + 100;
  Left := MainForm.Left + 100;
  Edit1.SetFocus;
end;

//HOTP
procedure TDataForm.HOTPChange(Sender: TObject);
begin
  if HOTP.Checked then HOTPCounter.Enabled := True
  else
    HOTPCounter.Enabled := False;
end;

end.
