unit totp_unit;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons;

type

  { TTOTPForm }

  TTOTPForm = class(TForm)
    Image1: TImage;
    Label1: TLabel;
    OkBtn: TSpeedButton;
    procedure FormKeyPress(Sender: TObject; var Key: char);
    procedure FormShow(Sender: TObject);
    procedure OkBtnClick(Sender: TObject);
  private

  public

  end;

var
  TOTPForm: TTOTPForm;

implementation

uses unit1;

  {$R *.lfm}

  { TTOTPForm }

procedure TTOTPForm.FormShow(Sender: TObject);
begin
  Top := MainForm.Top + 100;
  Left := MainForm.Left + 100;

  Width := Label1.Left + Label1.Width + 8;
  Height := OkBtn.Top + OkBtn.Height + 8;
end;

procedure TTOTPForm.FormKeyPress(Sender: TObject; var Key: char);
begin
  if Key = #13 then Close;
end;

procedure TTOTPForm.OkBtnClick(Sender: TObject);
begin
  TOTPForm.Close;
end;

end.
