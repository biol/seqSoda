program seqSoda;

uses
  Vcl.Forms,
  guiSeqSoda in 'guiSeqSoda.pas' {FormSeqSoda},
  oSeqSoda in 'oSeqSoda.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TFormSeqSoda, FormSeqSoda);
  Application.Run;
end.
