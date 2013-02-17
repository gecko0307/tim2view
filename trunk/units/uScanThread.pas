unit uScanThread;

interface

uses
  Classes, Windows, crc32, uCommon, uTIM, NativeXML;

type
  TScanThread = class(Classes.TThread)
  private
    { Private declarations }
    pFileToScan: string;
    pImageScan: boolean;
    pResult: PNativeXml;
    pFileSize: DWORD;
    pStatusText: string;
    pClearBufferPosition: DWORD;
    pClearBufferSize: DWORD;
    pSectorBufferSize: DWORD;
    pSrcFileStream: TFileStream;
    procedure SetStatusText;
    procedure UpdateProgressBar;
    procedure ClearAndNil(var HEAD: PTIMHeader); overload;
    procedure ClearAndNil(var CLUT: PCLUTHeader); overload;
    procedure ClearAndNil(var IMAGE: PIMAGEHeader); overload;
    procedure ClearAndNil(var TIMDATA: PTIMDataArray); overload;
    procedure AddResult(TIM: PTIM);
    procedure ClearSectorBuffer(SectorBuffer, ClearBuffer: PBytesArray);
  protected
    procedure Execute; override;
  public
    constructor Create(const FileToScan: string; fResult: PNativeXml);
    destructor Destroy; override;
    property Terminated;
  end;

implementation

uses
  uMain, uCDIMAGE, SysUtils;

const  
  cClearBufferSize = ((cTIMMaxSize div cSectorDataSize) + 1) * cSectorDataSize * 2;
  cSectorBufferSize = (cClearBufferSize div cSectorDataSize) * cSectorSize;

{ TScanThread }

constructor TScanThread.Create(const FileToScan: string; fResult: PNativeXml);
var
  Node: TXmlNode;
begin
  inherited Create(False);
  pClearBufferPosition := 0;
  pFileToScan := FileToScan;
  pFileSize := GetFileSZ(pFileToScan);
  pStatusText := '';

  pResult := fResult;
  pResult^.XmlFormat := xfCompact;

  pResult^.Root.Name := cResultsRootName;
  pResult^.Root.WriteAttributeString(cResultsAttributeVersion,
    cProgramVersion);
  Node := pResult^.Root.NodeNew(cResultsInfoNode);
  Node.WriteAttributeString(cResultsAttributeFile,
    ExtractFileName(pFileToScan));
  pImageScan := GetImageScan(pFileToScan);
  Node.WriteAttributeBool(cResultsAttributeImageFile, pImageScan);
  Node.WriteAttributeInteger(cResultsAttributeTimsCount, 0);
end;

procedure TScanThread.AddResult(TIM: PTIM);
var
  Node, AddedNode: TXmlNode;
  RWidth: WORD;
begin
  Node := pResult^.Root.NodeFindOrCreate(cResultsInfoNode);
  Node.WriteAttributeInteger(cResultsAttributeTimsCount, TIM^.dwTimNumber);

  Node := pResult^.Root.NodeFindOrCreate(cResultsTimsNode);

  AddedNode := Node.NodeNew(cResultsTimNode);
  AddedNode.WriteAttributeInteger(cResultsTimAttributeBitMode, TIM^.HEAD^.bBPP);
  RWidth := IWidthToRWidth(TIM^.HEAD, TIM^.IMAGE);
  AddedNode.WriteAttributeInteger(cResultsTimAttributeWidth, RWidth);
  AddedNode.WriteAttributeInteger(cResultsTimAttributeHeight,
    TIM^.IMAGE^.wHeight);
  AddedNode.WriteAttributeBool(cResultsTimAttributeGood, TIM^.bGOOD);
  AddedNode.WriteAttributeInteger(cResultsTimAttributeCLUTSize,
    GetTIMCLUTSize(TIM^.HEAD, TIM^.CLUT));
  AddedNode.WriteAttributeInteger(cResultsTimAttributeIMAGESize,
    GetTIMIMAGESize(TIM^.HEAD, TIM^.IMAGE));
  AddedNode.WriteAttributeString(cResultsTimAttributeFilePos,
                                 IntToHex(TIM^.dwTimPosition, 8));

  AddedNode.BufferWrite(TIM^.DATA^, TIM^.dwSIZE);
end;

procedure TScanThread.Execute;
var
  Node: TXmlNode;
  SectorBuffer, ClearBuffer: PBytesArray;
  TIM: PTIM;
  pScanFinished: Boolean;
  pRealBufSize, pTimPosition, pTIMNumber: DWORD;
begin
  if not CheckFileExists(pFileToScan) then Terminate;

  pSrcFileStream := TFileStream.Create(pFileToScan, fmOpenRead);

  if pImageScan then
    pSectorBufferSize := cSectorBufferSize
  else
    pSectorBufferSize := cClearBufferSize;

  pClearBufferSize := cClearBufferSize;

  SectorBuffer := GetMemory(pSectorBufferSize);
  ClearBuffer := GetMemory(pClearBufferSize);

  New(TIM);
  New(TIM^.HEAD);
  New(TIM^.CLUT);
  New(TIM^.IMAGE);
  TIM^.dwSIZE := 0;
  TIM^.dwTimPosition := 0;
  TIM^.dwTIMNumber := 0;
  TIM^.bGOOD := False;
  New(TIM^.DATA);

  pStatusText := sStatusBarScanningFile;
  Synchronize(SetStatusText);

  pRealBufSize := pSrcFileStream.Read(SectorBuffer^[0], pSectorBufferSize);
  ClearSectorBuffer(SectorBuffer, ClearBuffer);

  pScanFinished := False;
  pTIMNumber := 0;

  while True do
  begin
    if TIMisHERE(ClearBuffer, TIM, pClearBufferPosition) then
    begin
      if pImageScan then
        pTimPosition := pSrcFileStream.Position - pRealBufSize +
                        ((pClearBufferPosition - 1) div cSectorDataSize) *
                        cSectorSize +
                        ((pClearBufferPosition - 1) mod cSectorDataSize) +
                        cSectorInfoSize
      else
        pTimPosition := pSrcFileStream.Position - pRealBufSize +
                        (pClearBufferPosition - 1);

      TIM^.dwTimPosition := pTimPosition;
      inc(pTIMNumber);
      TIM^.dwTimNumber := pTIMNumber;
      AddResult(TIM);
    end;

    if pClearBufferPosition = (pClearBufferSize div 2) then
    begin
      if pScanFinished then Break;
      pScanFinished := (pSrcFileStream.Position = pFileSize);
      pClearBufferPosition := 0;
      Move(SectorBuffer^[pSectorBufferSize div 2], SectorBuffer^[0], pSectorBufferSize div 2);

      if pScanFinished then
      begin
        if pRealBufSize >= (pSectorBufferSize div 2) then   //Need to check file size
        pRealBufSize := pRealBufSize - (pSectorBufferSize div 2) ;
      end
      else
      begin
        pRealBufSize := pSrcFileStream.Read(SectorBuffer^[pSectorBufferSize div 2], pSectorBufferSize div 2);
        pRealBufSize := pRealBufSize + (pSectorBufferSize div 2);
      end;

      Synchronize(UpdateProgressBar);
      ClearSectorBuffer(SectorBuffer, ClearBuffer);
    end;
  end;
  ClearAndNil(TIM^.HEAD);
  ClearAndNil(TIM^.CLUT);
  ClearAndNil(TIM^.IMAGE);
  FreeMemory(SectorBuffer);
  FreeMemory(ClearBuffer);

  ClearAndNil(TIM^.DATA);
  Dispose(TIM);
  Synchronize(UpdateProgressBar);
  pSrcFileStream.Free;

 { T := GetTickCount - T;
  S := Format('Scan completed!' + #13#10 +
    'Time (secs): %d; TIMs: %d', [T div 1000, pTimsCount]);
  Text2Clipboard(S);
  MessageBox(Self.Handle, PAnsiChar(S),
    'Information', MB_OK + MB_ICONINFORMATION + MB_TOPMOST);  }

  pStatusText := sStatusBarCalculatingCRC;
  Synchronize(SetStatusText);

  Node := pResult^.Root.NodeFindOrCreate(cResultsInfoNode);
  Node.WriteAttributeString(cResultsAttributeCRC32, FileCRC32(pFileToScan));
end;

destructor TScanThread.Destroy;
begin
  pStatusText := '';
  Synchronize(SetStatusText);
  inherited;
end;

procedure TScanThread.SetStatusText;
begin
  frmMain.stbMain.Panels[0].Text := pStatusText;
end;

procedure TScanThread.ClearAndNil(var HEAD: PTIMHeader);
begin
  if HEAD = nil then
    Exit;
  Dispose(HEAD);

  HEAD := nil;
end;

procedure TScanThread.ClearAndNil(var CLUT: PCLUTHeader);
begin
  if CLUT = nil then
    Exit;
  Dispose(CLUT);

  CLUT := nil;
end;

procedure TScanThread.ClearAndNil(var IMAGE: PIMAGEHeader);
begin
  if IMAGE = nil then
    Exit;
  Dispose(IMAGE);

  IMAGE := nil;
end;

procedure TScanThread.UpdateProgressBar;
begin
  frmMain.pbProgress.Position := pSrcFileStream.Position;
end;

procedure TScanThread.ClearAndNil(var TIMDATA: PTIMDataArray);
begin
  if TIMDATA = nil then
    Exit;

  Dispose(TIMDATA);
  TIMDATA := nil;
end;

procedure TScanThread.ClearSectorBuffer(SectorBuffer, ClearBuffer: PBytesArray);
var
  i: DWORD;
begin
  FillChar(ClearBuffer^[0], pClearBufferSize, 0);
  if not pImageScan then
  begin
    Move(SectorBuffer^[0], ClearBuffer^[0], pClearBufferSize);
    Exit;
  end;
  for i := 1 to (pSectorBufferSize div cSectorSize) do
  begin
    Move(SectorBuffer^[(i - 1) * cSectorSize + cSectorInfoSize],
      ClearBuffer^[(i - 1) * cSectorDataSize], cSectorDataSize);
  end;
end;

end.
