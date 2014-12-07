unit oSeqSoda;

(* ottimizzazione dell'attraversamento della sodo
  avendo <n> barre ognuna con il suo tempo soda, qual'è la sequenza che fa passare dette barre in meno tempo?
  carico in aBaSo le mie barre
  le compatto in aSoBa

  luppo fino ad esaurimento
    trovo la migliore barra
    la sposto in aBaso
    pulisco

*)

interface uses classes;

var
  K_SingleMovSecs: integer = 100;  // tipica durata di una sequenza prelievo traslazione deposito
  K_TotalMovSecs : integer = 420;       // stima durata complessiva prelievo da soda ÷ prelievo da ultimo lavaggio
  MAX_DropSecs   : integer = 0;  // vincoli attuali
  PREV_PickupSecs: integer = 0;  // vincoli attuali
  MAX_PickupSecs : integer = 0;  // vincoli attuali

type
  TYellowBar = class
    BarID, SodaSecs, delaySecs: integer;
    function asString: string;
  end;
  TYellowBars = class
    dscr: string;
    aYellowBars: array of TYellowBar;
    procedure clear;
    procedure add(pBarID, pSodaSecs, pWaitSecs: integer);
    procedure addBar(pYellowBar: TYellowBar);
    function asString(pWithExtension: boolean = false): string;
    function count: integer;
    function popOldestWithSodaSecs(pSodaSecs: integer): TYellowBar;
  end;

  TSodaRecap = class
    SodaSecs, BarCount: integer;
  end;
  TSodaRecaps = class
    dscr: string;
    aSodaRecaps: array of TSodaRecap;
    procedure clear;
    procedure add(pYellowBar: TYellowBar);
    procedure loadFrom(pYellowBars: TYellowBars);
    function asString: string;
    function count: integer;
    procedure decrementOneWithSodaSecs(pSodaSecs: integer);
  end;

var
  YellowBars, SequencedBars: TYellowBars;   // barre da sequenziare e già sequenziate
  SodaRecaps: TSodaRecaps;   // oggetto di lavoro
  _log: TStrings;

procedure setupFromFile(pFName: string);
procedure buildSeq;

implementation uses SysUtils, Math;

procedure logga(s: string); begin _log.add(s) end;

procedure setupFromFile(pFName: string);
var s: string; sl1, sl2: TStrings; elle: integer;
begin
  YellowBars.clear;   elle := 0;
  sl1 := TStringList.Create;
  sl2 := TStringList.Create;
  try
    sl1.loadFromFile(pFName);
    for s in sl1 do begin
      sl2.Clear;
      ExtractStrings([' '], [], PChar(trim(s)), sl2);

      YellowBars.add(
        strToIntDef(sl2[0], 0),
        strToIntDef(sl2[1], 0),
        strToIntDef(sl2[2], 0)
      );
      inc(elle);
    end;
  finally
    sl1.free;
    sl2.Free;
  end;
  logga(YellowBars.asString);
  SequencedBars.clear;
  SodaRecaps.loadFrom(YellowBars);
  logga(SodaRecaps.asString);
end;

function TreatSEQ_calcPickup(pSingleMov, pTotalMov, pDropMAX, pPickupPrev, pPickupMax, pEtching: integer): integer;
(* ALL parameters in seconds
  pSingleMov : total duration of pickup + traslation + drop (es. 100)
  pTotalMov  : total duration from pickup from Etching to pickup from last rinsing (es. 420)
               this is also the futurePickupGate parameter and specifies the minimum
               interval between 2 consecutive pickups from any soda tanks
  pDropMAX   : greatest drop so far (begin of treatment for previous bar)
  pPickupPrev: pickup for previous bar (end of treatment for previous bar)
  pPickupMax : greatest pickup so far (greatest end of treatment so far)
  pEtching   : duration of soda for this bar
  ==> returns the minimum pickup for this bar
*)
var myDrop, myPickup: integer;   // drop and pickup for current bar
begin
  myDrop   := pDropMAX + pSingleMov;  // this bar could enter ASAP after previous bar drop
  myPickup := myDrop   + pEtching  ;
  while (abs(myPickup - pPickupPrev) < pTotalMov) or (abs(myPickup - pPickupMAX) < pTotalMov) do begin
    // this pickup if not far enough from existing pickups
    if pPickupPrev < pPickupMAX then begin
      myPickup := max(myPickup, pPickupPrev + pTotalMov);   // cannot shrink, iterate ...
      pPickupPrev := pPickupMAX;  // it's a trick just for not passing here anymore
    end else begin
      myPickup := max(myPickup, pPickupMAX + pTotalMov);   // cannot shrink, success !!!
    end;
  end;
  // myDrop := myPickup - pEtching;
  // NON controllare che questo prelievo non cada quando il carro è occupato ...
  // se capita dovrei portarlo avanti di quanto basta e ripartire da "QUI:" ma NON lo faccio
  result := myPickup
end;

function TreatSEQ_bestSodaSces: integer;
var
  candidateSodaSecs, candidatePickupSecs, myPickup: integer;
  sr: TSodaRecap; bestBar: TYellowBar;
begin
  candidateSodaSecs := 0;
  candidatePickupSecs := 0;
  for sr in SodaRecaps.aSodaRecaps do begin
    myPickup := TreatSEQ_calcPickup(K_SingleMovSecs, K_TotalMovSecs, MAX_DropSecs, PREV_PickupSecs, MAX_PickupSecs, sr.SodaSecs);
    if (candidateSodaSecs = 0) or (candidatePickupSecs > myPickup) then begin
      candidateSodaSecs := sr.SodaSecs;
      candidatePickupSecs := myPickup;
    end;
  end;
  // sr.SodaSecs is the "best" (greedy) solution: find oldest bar with this sodaSecs and put in sequence
  bestBar := YellowBars.popOldestWithSodaSecs(candidateSodaSecs);
  bestBar.delaySecs := candidatePickupSecs - candidateSodaSecs;   // when this bar should enter soda tank
  SequencedBars.addBar(bestBar);
  SodaRecaps.decrementOneWithSodaSecs(candidateSodaSecs);
  MAX_DropSecs := bestBar.delaySecs;
  PREV_PickupSecs := candidatePickupSecs;
  if MAX_PickupSecs < PREV_PickupSecs then MAX_PickupSecs := PREV_PickupSecs;
end;

procedure buildSeq;   // find "best" seq for BaSos and put in SeqSodas
// greedy algorithm
begin
  while YellowBars.count > 0 do TreatSEQ_bestSodaSces;
  logga(SequencedBars.asString(true));
end;


{ TYellowBar }

function TYellowBar.asString: string;
begin
  result := Format('%2d   %4d   %5d', [BarID, SodaSecs, delaySecs])
end;

{ TSodaRecaps }

procedure TSodaRecaps.add(pYellowBar: TYellowBar);
var sb: TSodaRecap;
begin
  for sb in aSodaRecaps do begin
    if sb.SodaSecs = pYellowBar.SodaSecs then begin
      inc(sb.BarCount);
      exit
    end;
  end;
  setLength(aSodaRecaps, Length(aSodaRecaps) + 1);
  aSodaRecaps[high(aSodaRecaps)] := TSodaRecap.Create;
  with aSodaRecaps[high(aSodaRecaps)] do begin
    SodaSecs := pYellowBar.SodaSecs;
    BarCount := 1;
  end;
end;

function TSodaRecaps.asString: string;
var sl: TStrings; sb: TSodaRecap;
begin
  sl := TStringList.Create;
  try
    sl.Add('');
    sl.Add(dscr + ':');
    for sb in aSodaRecaps do begin
      sl.Add(Format('%.4d   %.2d', [sb.SodaSecs, sb.BarCount]))
    end;
    sl.Add('=== ' + IntToStr(count));
    result := sl.Text;
  finally
    sl.Free
  end;
end;

procedure TSodaRecaps.clear;
begin
  setLength(aSodaRecaps, 0)
end;

function TSodaRecaps.count: integer;
begin
  result := length(aSodaRecaps)
end;

procedure TSodaRecaps.loadFrom(pYellowBars: TYellowBars);
var bs: TYellowBar;
begin
  clear;
  for bs in pYellowBars.aYellowBars do add(bs)
end;

procedure TSodaRecaps.decrementOneWithSodaSecs(pSodaSecs: integer);
var i: integer;  timeToDelete: boolean;
begin
  timeToDelete := False;
  for i := 0 to high(aSodaRecaps) do begin
    if timeToDelete then begin
      aSodaRecaps[i - 1] := aSodaRecaps[i];
    end else if aSodaRecaps[i].SodaSecs = pSodaSecs then begin
      dec(aSodaRecaps[i].BarCount);
      if aSodaRecaps[i].BarCount = 0 then timeToDelete := True;
    end;
  end;
  if timeToDelete then setLength(aSodaRecaps, length(aSodaRecaps) - 1)
end;

{ TYellowBars }

procedure TYellowBars.add(pBarID, pSodaSecs, pWaitSecs: integer);
var myYellowBar: TYellowBar;
begin
  myYellowBar := TYellowBar.Create;
  with myYellowBar do begin
    BarID    := pBarID;
    SodaSecs := pSodaSecs;
    delaySecs := pWaitSecs;
  end;
  addBar(myYellowBar);
end;

procedure TYellowBars.addBar(pYellowBar: TYellowBar);
begin
  setLength(aYellowBars, Length(aYellowBars) + 1);
  aYellowBars[high(aYellowBars)] := pYellowBar;
end;

function TYellowBars.asString(pWithExtension: boolean = false): string;
var sl: TStrings; bs: TYellowBar; s: string; iSecs, prevSecs: integer;
begin                         prevSecs := 0;
  sl := TStringList.Create;
  try
    sl.Add('');
    sl.Add(dscr + ':');
    for bs in aYellowBars do begin
      s := bs.asString;
      if pWithExtension then begin
        iSecs := bs.SodaSecs + bs.delaySecs;
        s := Format('%s   %5d  +%d', [s, iSecs, iSecs - prevSecs]);
        prevSecs := iSecs;
      end;
      sl.Add(s)
    end;
    sl.Add('=== ' + IntToStr(count));
    result := sl.Text;
  finally
    sl.Free
  end;
end;

procedure TYellowBars.clear;
begin
  setLength(aYellowBars, 0);
end;

function TYellowBars.count: integer;
begin
  result := length(aYellowBars)
end;


function TYellowBars.popOldestWithSodaSecs(pSodaSecs: integer): TYellowBar;   // oldest = greatest delaySecs
var i, candidateBar, candidateWaitSecs: integer;
begin
  result := nil;
  for i := 0 to high(aYellowBars) do if aYellowBars[i].SodaSecs = pSodaSecs then begin
    if (result = nil) or (candidateWaitSecs < aYellowBars[i].delaySecs) then begin
      result := aYellowBars[i];
      candidateWaitSecs := aYellowBars[i].delaySecs;
      candidateBar := i;
    end;
  end;
  for i := candidateBar + 1 to high(aYellowBars) do aYellowBars[i - 1] := aYellowBars[i];
  setLength(aYellowBars, length(aYellowBars) - 1);
end;




initialization
  YellowBars    := TYellowBars.Create; YellowBars.dscr    := 'YellowBars';
  SequencedBars := TYellowBars.Create; SequencedBars.dscr := 'SequencedBars';
  SodaRecaps    := TSodaRecaps.Create; SodaRecaps.dscr    := 'SodaRecaps';

  MAX_DropSecs := 0;
  PREV_PickupSecs := 0;
  MAX_PickupSecs := 0;

finalization
  YellowBars.Free;
  SequencedBars.Free;
  SodaRecaps.Free;

  // ToDo: salvo i vincoli?

end.
