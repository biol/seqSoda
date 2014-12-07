unit guiSeqSoda;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils, System.Variants, System.Classes, Vcl.Graphics,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls, Vcl.ExtCtrls;

type
  TFormSeqSoda = class(TForm)
    Panel1: TPanel;
    Panel2: TPanel;
    MemoLOG: TMemo;
    btnLoad: TButton;
    procedure FormCreate(Sender: TObject);
    procedure btnLoadClick(Sender: TObject);
  private
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FormSeqSoda: TFormSeqSoda;

implementation uses oSeqSoda;

{$R *.dfm}



procedure TFormSeqSoda.btnLoadClick(Sender: TObject);
begin
  oSeqSoda.setupFromFile('seqSoda.txt');
  oSeqSoda.buildSeq;
end;

procedure TFormSeqSoda.FormCreate(Sender: TObject);
begin
  oSeqSoda._log := MemoLOG.Lines
end;

end.
