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
    ComboBox1: TComboBox;
    Edit1: TEdit;
    Edit2: TEdit;
    Label1: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    SpinEdit1: TSpinEdit;
    TOTPini: TIniPropStorage;
    procedure ApplyBtnClick(Sender: TObject);
    procedure FormCloseQuery(Sender: TObject; var CanClose: boolean);
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormShow(Sender: TObject);
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

//Применить
procedure TDataForm.ApplyBtnClick(Sender: TObject);
begin
  //Если Имя или Ключ не введены = Выход
  if (Edit1.Text = '') or (Edit2.Text = '') then Exit;

  //Редактирование записи
  if (MainForm.ListBox1.SelCount <> 0) and (TOTPini.IniFileName <> '') then
  begin
    //  ShowMessage('EDIT');
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
end;

//Нужно от дубликатов записей
procedure TDataForm.FormCloseQuery(Sender: TObject; var CanClose: boolean);
begin
  TOTPini.IniFileName := '';
end;

procedure TDataForm.FormKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then ApplyBtn.Click;
  if Key = #27 then DataForm.Close;
end;

procedure TDataForm.FormShow(Sender: TObject);
begin
  Top := MainForm.Top + 100;
  Left := MainForm.Left + 100;
  Edit1.SetFocus;
end;

end.
