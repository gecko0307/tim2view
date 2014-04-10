unit uMain;

interface

uses
  Winapi.Windows, Winapi.Messages, System.SysUtils,
  System.Classes, Vcl.Graphics, uEventWaitThread,
  Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.Grids, Vcl.ComCtrls,
  Vcl.ExtCtrls, Vcl.Menus, Vcl.StdCtrls, uScanThread, uCommon,
  Winapi.ShellAPI, uDrawTIM, Vcl.ExtDlgs, uTIM, System.Actions,
  Vcl.ActnList, uScanResult, System.Types, System.Generics.Collections,
  uSettings;

const
  WM_COMMANDARRIVED = WM_USER + 1;

type
  TfrmMain = class(TForm)
    dlgOpenFile: TOpenDialog;
    mmMain: TMainMenu;
    mnFile: TMenuItem;
    mnScanFile: TMenuItem;
    mnScanDir: TMenuItem;
    N1: TMenuItem;
    mnCloseFile: TMenuItem;
    mnExit: TMenuItem;
    mnTIM: TMenuItem;
    mnReplaceIn: TMenuItem;
    mnHelp: TMenuItem;
    mnSVN: TMenuItem;
    mnSite: TMenuItem;
    N3: TMenuItem;
    mnAbout: TMenuItem;
    pbProgress: TProgressBar;
    mnConfig: TMenuItem;
    pnlStatus: TPanel;
    lblStatus: TLabel;
    btnStopScan: TButton;
    mnCloseAllFiles: TMenuItem;
    mnSaveToPNG: TMenuItem;
    dlgSavePNG: TSavePictureDialog;
    mnSaveTIM: TMenuItem;
    dlgSaveTIM: TSaveDialog;
    cbbFiles: TComboBox;
    pnlMain: TPanel;
    splMain: TSplitter;
    pnlList: TPanel;
    lvList: TListView;
    pnlImageOptions: TPanel;
    cbbTranspMode: TComboBox;
    grdCurrClut: TDrawGrid;
    pnlImage: TPanel;
    splImageClut: TSplitter;
    dlgColor: TColorDialog;
    actList: TActionList;
    actScanFile: TAction;
    actScanDir: TAction;
    actCloseFile: TAction;
    actCloseFiles: TAction;
    actExit: TAction;
    N4: TMenuItem;
    actExtractTim: TAction;
    actReplaceTim: TAction;
    actTim2Png: TAction;
    actOpenRepo: TAction;
    actOpenLab: TAction;
    actAbout: TAction;
    pmList: TPopupMenu;
    ExtractTIM1: TMenuItem;
    ReplaceTIM1: TMenuItem;
    N2: TMenuItem;
    SaveasPNG1: TMenuItem;
    cbbBitMode: TComboBox;
    actStretch: TAction;
    actTimInfo: TAction;
    mnTIMInfo: TMenuItem;
    IMInfo1: TMenuItem;
    actAssocTims: TAction;
    mnAssociate: TMenuItem;
    N6: TMenuItem;
    actExtractList: TAction;
    ExtractTIMs1: TMenuItem;
    pbTim: TImage;
    btnShowClut: TButton;
    cbbCLUT: TComboBox;
    actChangeBackColor: TAction;
    actReturnFocus: TAction;
    actDrawSelectedTim: TAction;
    procedure btnStopScanClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure lvListData(Sender: TObject; Item: TListItem);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure cbbFilesChange(Sender: TObject);
    procedure cbbCLUTChange(Sender: TObject);
    procedure grdCurrClutDrawCell(Sender: TObject; ACol, ARow: Integer; Rect: TRect; State: TGridDrawState);
    procedure grdCurrClutDblClick(Sender: TObject);
    procedure actScanFileExecute(Sender: TObject);
    procedure actScanDirExecute(Sender: TObject);
    procedure actCloseFileExecute(Sender: TObject);
    procedure actCloseFilesExecute(Sender: TObject);
    procedure actExitExecute(Sender: TObject);
    procedure actExtractTimExecute(Sender: TObject);
    procedure actReplaceTimExecute(Sender: TObject);
    procedure actTim2PngExecute(Sender: TObject);
    procedure actOpenRepoExecute(Sender: TObject);
    procedure actOpenLabExecute(Sender: TObject);
    procedure actAboutExecute(Sender: TObject);
    procedure actStretchExecute(Sender: TObject);
    procedure actTimInfoExecute(Sender: TObject);
    procedure actAssocTimsExecute(Sender: TObject);
    procedure actExtractListExecute(Sender: TObject);
    procedure cbbTranspModeChange(Sender: TObject);
    procedure btnShowClutClick(Sender: TObject);
    procedure lvListChange(Sender: TObject; Item: TListItem;
      Change: TItemChange);
    procedure actReturnFocusExecute(Sender: TObject);
    procedure actDrawSelectedTimExecute(Sender: TObject);
  private
    { Private declarations }
    // pResult: PNativeXml;
    ScanThreads: TList<TScanThread>;
    PNG: PPNGImage;
    LastDir: string;
    WaitThread: TEventWaitThread;
    StartedScans: Integer;
    Settings: TSettings;

    function ScanRes: TScanResult;
    procedure SetListCount(Count: Integer);
    procedure ScanFinished(Sender: TObject);
    procedure CheckButtonsAndMainMenu;
    procedure ScanPath(const Path: string);
    procedure ScanFile(const FileName: string);
    procedure ScanDirectory(const Directory: string);
    function ListIdx: Integer;
    function TimIdx(Index: Integer): TScanTim;
    function SelTim(NewBitMode: Integer = $FF): PTIM;
    function SelTimName: string;
    procedure DrawSelTim;
    procedure DrawSelClut;
    procedure UpdateCLUTInfo;
    procedure SetCLUTListToNoCLUT;
    function ForceForegroundWindow(hwnd: THandle): Boolean;
    procedure ShowItem();
  protected
    procedure WMDropFiles(var Msg: TWMDropFiles); message WM_DROPFILES;
    procedure WMCommandArrived(var Message: TMessage); message WM_COMMANDARRIVED;
    function ReadPathFromMailslot: string;
  public
    { Public declarations }
    ScanResult: TList<TScanResult>;
    function CheckForFileOpened(const FileName: string): boolean;
  end;

var
  frmMain: TfrmMain;
  ServerMailSlot: THandle;

implementation

uses
  uCDIMAGE, uBrowseForFolder, System.Win.Registry;

{$R *.dfm}

function TfrmMain.ForceForegroundWindow(hwnd: THandle): Boolean;
const
  SPI_GETFOREGROUNDLOCKTIMEOUT = $2000;
  SPI_SETFOREGROUNDLOCKTIMEOUT = $2001;
var
  ForegroundThreadID: DWORD;
  ThisThreadID: DWORD;
  timeout: DWORD;
begin
  if IsIconic(hwnd) then ShowWindow(hwnd, SW_RESTORE);

  if GetForegroundWindow = hwnd then Result := True
  else
  begin
    // Windows 98/2000 doesn't want to foreground a window when some other
    // window has keyboard focus

    if ((Win32Platform = VER_PLATFORM_WIN32_NT) and (Win32MajorVersion > 4)) or
      ((Win32Platform = VER_PLATFORM_WIN32_WINDOWS) and
      ((Win32MajorVersion > 4) or ((Win32MajorVersion = 4) and
      (Win32MinorVersion > 0)))) then
    begin
      Result := False;
      ForegroundThreadID := GetWindowThreadProcessID(GetForegroundWindow, nil);
      ThisThreadID := GetWindowThreadPRocessId(hwnd, nil);
      if AttachThreadInput(ThisThreadID, ForegroundThreadID, True) then
      begin
        BringWindowToTop(hwnd); // IE 5.5 related hack
        SetForegroundWindow(hwnd);
        AttachThreadInput(ThisThreadID, ForegroundThreadID, False);
        Result := (GetForegroundWindow = hwnd);
      end;
      if not Result then
      begin
        // Code by Daniel P. Stasinski
        SystemParametersInfo(SPI_GETFOREGROUNDLOCKTIMEOUT, 0, @timeout, 0);
        SystemParametersInfo(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, TObject(0),
          SPIF_SENDCHANGE);
        BringWindowToTop(hwnd); // IE 5.5 related hack
        SetForegroundWindow(hWnd);
        SystemParametersInfo(SPI_SETFOREGROUNDLOCKTIMEOUT, 0, TObject(timeout), SPIF_SENDCHANGE);
      end;
    end
    else
    begin
      BringWindowToTop(hwnd); // IE 5.5 related hack
      SetForegroundWindow(hwnd);
    end;

    Result := (GetForegroundWindow = hwnd);
  end;
end;

function TfrmMain.ReadPathFromMailslot: string;
var
  MessageSize: DWORD;
begin
  GetMailslotInfo(ServerMailSlot, nil, MessageSize, nil, nil);

  if MessageSize = MAILSLOT_NO_MESSAGE then
  begin
    Result := '';
    Exit;
  end;

  SetLength(Result, MessageSize div SizeOf(Char));
  ReadFile(ServerMailSlot, Result[1], MessageSize * SizeOf(Char), MessageSize, nil);
  Result := Trim(Result);
end;

procedure TfrmMain.WMCommandArrived(var Message: TMessage);
var
  path: string;
begin
  ForceForegroundWindow(Self.Handle);
  path := ReadPathFromMailslot;
  ScanPath(path);
end;

procedure TfrmMain.actAboutExecute(Sender: TObject);
begin
  MessageBox(Handle, 'Some "about strings" should be here!:)', 'About', MB_OK + MB_ICONINFORMATION);
end;

procedure TfrmMain.actAssocTimsExecute(Sender: TObject);
var
  reg: TRegistry;
begin
  reg := TRegistry.Create;

  try
    reg.RootKey := HKEY_CURRENT_USER;
    reg.OpenKey('Software\Classes\.tim', True);
    reg.WriteString('', 'TimFile');
    reg.CloseKey;

    reg.OpenKey('Software\Classes\TimFile', True);
    reg.WriteString('', 'Tim File Format');
    reg.CloseKey;
    reg.OpenKey('Software\Classes\TimFile\DefaultIcon', True);
    reg.WriteString('', '"' + ParamStr(0) +'",0');
    reg.CloseKey;
    reg.OpenKey('Software\Classes\TimFile\shell\Open\Command', True);
    reg.WriteString('', '"' + ParamStr(0) + '" "%1"');
    reg.CloseKey;
  finally
    reg.Free;
  end;
end;

procedure TfrmMain.actCloseFileExecute(Sender: TObject);
begin
  ScanRes.Free;
  ScanResult.Delete(cbbFiles.ItemIndex);
  lvList.Items.BeginUpdate;
  lvList.Items.Count := 0;
  lvList.Items.EndUpdate;
  lblStatus.Caption := '';
  actTimInfo.Enabled := False;
  actTimInfo.Caption := 'TIM Info';
  lvList.Column[0].Caption := '# / 0';

  UpdateCLUTInfo;
  DrawSelTim;
  DrawSelClut;

  cbbFiles.Items.Delete(cbbFiles.ItemIndex);

  CheckButtonsAndMainMenu;

  if cbbFiles.Enabled then
  begin
    cbbFiles.ItemIndex := cbbFiles.Items.Count - 1;
    cbbFilesChange(Self);
  end;
end;

procedure TfrmMain.actCloseFilesExecute(Sender: TObject);
begin
  while cbbFiles.Items.Count > 0 do
  begin
    cbbFiles.Items.BeginUpdate;
    actCloseFile.Execute;
    cbbFiles.Items.EndUpdate;
  end;
end;

procedure TfrmMain.actDrawSelectedTimExecute(Sender: TObject);
begin
  DrawSelTim;
end;

procedure TfrmMain.actExitExecute(Sender: TObject);
begin
  Close;
end;

procedure TfrmMain.actExtractListExecute(Sender: TObject);
var
  I, OFFSET, BIT_MODE, SIZE: Integer;
  FName, TIM_NAME, Path: string;
  IsImage: Boolean;
  ScanTim: TScanTim;
  TIM: PTIM;
begin
  lblStatus.Caption := sStatusBarTimsExtracting;

  FName := ScanRes.ScanFile;
  IsImage := ScanRes.IsImage;

  for I := 1 to ScanRes.Count do
  begin
    ScanTim := TimIdx(I - 1);
    OFFSET := ScanTim.Position;
    SIZE := ScanTim.Size;
    BIT_MODE := ScanTim.BitMode;

    TIM_NAME := Format(cAutoExtractionTimFormat, [ExtractJustName(FName), I, BIT_MODE]);

    Path := IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0)) + cExtractedTimsDir);
    CreateDir(Path);
    Path := IncludeTrailingPathDelimiter(Path + ExtractFileName(FName));
    CreateDir(Path);

    TIM := LoadTimFromFile(FName, OFFSET, IsImage, SIZE);
    SaveTimToFile(Path + TIM_NAME, TIM);
    FreeTIM(TIM);
  end;
  lblStatus.Caption := sStatusBarTimsExtracted;
  MessageBeep(MB_ICONINFORMATION);
end;

procedure TfrmMain.actExtractTimExecute(Sender: TObject);
var
  TIM: PTIM;
begin
  dlgSaveTIM.FileName := SelTimName;

  if not dlgSaveTIM.Execute then Exit;

  TIM := SelTim;
  SaveTimToFile(dlgSaveTIM.FileName, TIM);
  FreeTIM(TIM);
end;

procedure TfrmMain.actOpenLabExecute(Sender: TObject);
begin
  ShellExecute(Handle, 'open', 'tim2view.googlecode.com', nil, nil, SW_SHOW);
end;

procedure TfrmMain.actOpenRepoExecute(Sender: TObject);
begin
  ShellExecute(Handle, 'open', 'tim2view.googlecode.com', nil, nil, SW_SHOW);
end;

procedure TfrmMain.actReplaceTimExecute(Sender: TObject);
begin
  if not dlgOpenFile.Execute then Exit;

  if GetFileSizeAPI(dlgOpenFile.FileName) > cTIMMaxSize then Exit;

  ReplaceTimInFile(ScanRes.ScanFile, dlgOpenFile.FileName, TimIdx(ListIdx).Position, ScanRes.IsImage);
  ShowItem;
  MessageBeep(MB_ICONINFORMATION);
end;

procedure TfrmMain.actReturnFocusExecute(Sender: TObject);
begin
  if lvList.Enabled then lvList.SetFocus;
end;

procedure TfrmMain.actScanDirExecute(Sender: TObject);
var
  SelectedDir: string;
begin
  SelectedDir := BrowseForFolder(Handle, sSelectDirCaption, LastDir);
  if DirectoryExists(SelectedDir) then
  begin
    ScanPath(SelectedDir);
    LastDir := SelectedDir;
    Settings.LastDir := LastDir;
  end;
end;

procedure TfrmMain.actScanFileExecute(Sender: TObject);
var
  I: Integer;
begin
  if not dlgOpenFile.Execute then Exit;

  for I := 1 to dlgOpenFile.Files.Count do
    ScanPath(dlgOpenFile.Files.Strings[I - 1]);
end;

procedure TfrmMain.actStretchExecute(Sender: TObject);
begin
  Settings.StretchMode := actStretch.Checked;
  actDrawSelectedTimExecute(Self);
end;

procedure TfrmMain.actTim2PngExecute(Sender: TObject);
var
  FName: string;
begin
  FName := SelTimName;
  FName := ChangeFileExt(FName, '.png');
  dlgSavePNG.FileName := FName;

  if not dlgSavePNG.Execute then Exit;

  PNG^.SaveToFile(dlgSavePNG.FileName);
end;

procedure TfrmMain.actTimInfoExecute(Sender: TObject);
const
  Tab = #$09;
  Row = #13#10;
var
  Info, IsGoodTIM: string;
  Index: Integer;
  TIM: PTIM;
begin
  if actTimInfo.Enabled then
  begin
    Index := ListIdx;
    TIM := SelTim;

    if TIMIsGood(TIM) then
      IsGoodTIM := 'YES'
    else
      IsGoodTIM := 'NO';

    Info := Format('"%s" Information' + Row + 'Number:' + Tab + '%d' + Row +
      'Position:' + Tab + '0x%x' + Row + 'BitMode:' + Tab + '%d' + Row + 'Good:'
      + Tab + '%s' + Row + Row +

      'HEADER INFO' + Row + 'Version:' + Tab + '%d' + Row + 'BPP:' + Tab + '%d'
      + Row + Row, [SelTimName, Index + 1, TimIdx(Index).Position,
      BppToBitMode(TIM), IsGoodTIM,

      GetTimVersion(TIM), GetTimBPP(TIM)]);

    if TIMHasCLUT(TIM) then
      Info := Format(Info + 'CLUT INFO' + Row + 'Size (Header):' + Tab + '%d' +
        Row + 'Size (Real):' + Tab + '%d' + Row + 'VRAM X Pos:' + Tab + '%d' +
        Row + 'VRAM Y Pos:' + Tab + '%d' + Row + 'CLUTs Count:' + Tab + '%d' +
        Row + 'Colors in 1 CLUT:' + Tab + '%d' + Row + Row,
        [GetTimClutSizeHeader(TIM), GetTimClutSize(TIM), GetTimClutVRAMX(TIM),
        GetTimClutVRAMY(TIM), GetTIMClutsCount(TIM), GetTimColorsCount(TIM)]);

    Info := Format(Info + 'IMAGE INFO' + Row + 'Size (Header):' + Tab + '%d' +
      Row + 'Size (Real):' + Tab + '%d' + Row + 'VRAM X Pos:' + Tab + '%d' + Row
      + 'VRAM Y Pos:' + Tab + '%d' + Row + 'Width (Header):' + Tab + '%d' + Row
      + 'Width (Real):' + Tab + '%d' + Row + 'Height (Real):' + Tab + '%d',
      [GetTimImageSizeHeader(TIM), GetTimImageSize(TIM), GetTimImageVRAMX(TIM),
      GetTimImageVRAMY(TIM), GetTimWidth(TIM), GetTimRealWidth(TIM),
      GetTimHeight(TIM)]);

    case MessageBox(Handle,
      PWideChar(Info + Row + Row +
      'If you want to copy this info to clipboard press "YES" button.'),
      'Information', MB_OKCANCEL + MB_ICONINFORMATION + MB_TOPMOST) of
      IDOK:
        Text2Clipboard(Info);
    end;

    FreeTIM(TIM);
  end;
end;

procedure TfrmMain.btnShowClutClick(Sender: TObject);
begin
  grdCurrClut.Visible := not grdCurrClut.Visible;
  DrawSelClut;
  actReturnFocusExecute(Self);
end;

procedure TfrmMain.btnStopScanClick(Sender: TObject);
var
  I: Integer;
begin
  if ScanThreads.Count = 0 then Exit;

  for I := 1 to ScanThreads.Count do
    ScanThreads[I - 1].StopScan := True;

  ScanThreads.Clear;
  StartedScans := 0;
  btnStopScan.Tag := NativeInt(True);

  ScanFinished(nil);

  actReturnFocusExecute(Self);
end;

procedure TfrmMain.cbbFilesChange(Sender: TObject);
begin
  SetListCount(ScanRes.Count);

  actReturnFocusExecute(Self);
  lvList.Selected := nil;
  lvList.Items[0].Focused := True;
  lvList.Items[0].Selected := True;
end;

procedure TfrmMain.cbbTranspModeChange(Sender: TObject);
begin
  Settings.TranspMode := cbbTranspMode.ItemIndex;
  actDrawSelectedTimExecute(Self);
end;

procedure TfrmMain.cbbCLUTChange(Sender: TObject);
begin
  actDrawSelectedTimExecute(Self);
  DrawSelClut;
end;

function TfrmMain.CheckForFileOpened(const FileName: string): boolean;
var
  I: Integer;
begin
  Result := False;

  for I := 1 to ScanResult.Count do
    if ScanResult[I - 1].ScanFile = FileName then
    begin
      Result := True;
      Exit;
    end;
end;

procedure TfrmMain.CheckButtonsAndMainMenu;
begin
  cbbFiles.Enabled := (cbbFiles.Items.Count <> 0);

  lvList.Enabled := cbbFiles.Enabled;
  actExtractList.Enabled := cbbFiles.Enabled;
  actCloseFile.Enabled := cbbFiles.Enabled;
  actCloseFiles.Enabled := cbbFiles.Enabled;
  actReplaceTim.Enabled := (lvList.SelCount = 1);
  actTim2Png.Enabled := (PNG^ <> nil) and actReplaceTim.Enabled;
  actExtractTim.Enabled := actReplaceTim.Enabled;

  cbbCLUT.Enabled := actReplaceTim.Enabled;
  btnShowClut.Enabled := actReplaceTim.Enabled;
  cbbTranspMode.Enabled := actReplaceTim.Enabled;
  cbbBitMode.Enabled := actReplaceTim.Enabled;
  //actStretch.Enabled := actReplaceTim.Enabled;
end;

function TfrmMain.SelTIM(NewBitMode: Integer = $FF): PTIM;
var
  P: Integer;
begin
  Result := nil;

  if lvList.Selected = nil then Exit;

  P := TimIdx(ListIdx).Position;
  Result := LoadTimFromFile(ScanRes.ScanFile, P, ScanRes.IsImage, TimIdx(ListIdx).Size);

  if NewBitMode = $FF then Exit;
  Result^.HEAD^.bBPP := NewBitMode;
end;

function TfrmMain.SelTimName: string;
begin
  Result := Format(cAutoExtractionTimFormat, [ExtractJustName(ScanRes.ScanFile), ListIdx + 1, TimIdx(ListIdx).BitMode]);
end;

procedure TfrmMain.DrawSelClut;
var
  TIM: PTIM;
begin
  if not grdCurrClut.Visible then Exit;

  ClearGrid(@grdCurrCLUT);

  TIM := SelTim;
  if TIM = nil then
  begin
    grdCurrCLUT.ColCount := 1;
    grdCurrCLUT.RowCount := 1;
    Exit;
  end;

  grdCurrCLUT.Enabled := TIMHasCLUT(TIM);

  if TIMHasCLUT(TIM) then
    DrawCLUT(TIM, cbbCLUT.ItemIndex, @grdCurrCLUT)
  else
  begin
    grdCurrCLUT.ColCount := 1;
    grdCurrCLUT.RowCount := 1;
  end;

  FreeTIM(TIM);
end;

procedure TfrmMain.DrawSelTim;
var
  TIM: PTIM;
  Index: Integer;
  mode: Byte;
begin
  pbTim.Picture := nil;

  case cbbBitMode.ItemIndex of
    1: mode := cTIM4C;
    2: mode := cTIM8C;
    3: mode := cTIM16NC;
    4: mode := cTIM24NC;
  else
    mode := $FF;
  end;

  TIM := SelTim(mode);
  if TIM = nil then Exit;

  if PNG^ <> nil then
  begin
    PNG^.Free;
    PNG^ := nil;
  end;

  if cbbCLUT.Text = sThisTimHasNoClut then
    Index := -1
  else
    Index := cbbCLUT.ItemIndex;

  TimToPNG(TIM, Index, PNG, cbbTranspMode.ItemIndex);
  PNG.AssignTo(pbTim.Picture.Bitmap);
  FreeTIM(TIM);

  pbTim.Stretch := actStretch.Checked;
end;

function TfrmMain.ScanRes: TScanResult;
begin
  Result := ScanResult[cbbFiles.ItemIndex];
end;

procedure TfrmMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  actCloseFiles.Execute;
  ScanThreads.Free;
  ScanResult.Free;

  if PNG^ <> nil then PNG^.Free;
  Dispose(PNG);

  Settings.SaveToFile;
  Settings.Free;
end;

procedure TfrmMain.FormCreate(Sender: TObject);
var
  hGridRect: TGridRect;
begin
  Settings := TSettings.Create;
  Settings.LoadFromFile;

  actStretch.Checked := Settings.StretchMode;
  cbbTranspMode.ItemIndex := Settings.TranspMode;
  LastDir := Settings.LastDir;

  hGridRect.Top := -1;
  hGridRect.Left := -1;
  hGridRect.Right := -1;
  hGridRect.Bottom := -1;
  grdCurrClut.Selection := hGridRect;

  pbTim.Parent.DoubleBuffered := true;

  ScanThreads := TList<TScanThread>.Create;
  ScanResult := TList<TScanResult>.Create;
  StartedScans := 0;
  New(PNG);
  PNG^ := nil;

  SetCLUTListToNoCLUT;
  Caption := Format('%s v%s', [cProgramName, cProgramVersion]);
  DragAcceptFiles(Handle, True);
  CheckButtonsAndMainMenu;

  if ParamCount > 0 then ScanPath(ParamStr(1));

  WaitThread := TEventWaitThread.Create(False);
  WaitThread.FreeOnTerminate := True;
end;

procedure TfrmMain.grdCurrClutDblClick(Sender: TObject);
var
  TIM: PTIM;
  I, SELECTED_CELL, W, DIALOG_COLOR, CLUT_NUM: Integer;
  R, G, B: Byte;
  CLUT_COLOR: TCLUT_COLOR;
begin
  TIM := SelTim;
  if TIM = nil then Exit;

  SELECTED_CELL := grdCurrCLUT.Row * grdCurrCLUT.ColCount + grdCurrCLUT.Col;
  W := GetTimColorsCount(TIM);

  if (SELECTED_CELL + 1) > W then
  begin
    FreeTIM(TIM);
    Exit;
  end;

  CLUT_NUM := cbbCLUT.ItemIndex;
  dlgColor.CustomColors.Clear;

  for I := 1 to 16 do
  begin
    CLUT_COLOR := GetCLUTColor(TIM, CLUT_NUM, I - 1);
    R := CLUT_COLOR.R;
    G := CLUT_COLOR.G;
    B := CLUT_COLOR.B;
    dlgColor.CustomColors.Add(Format('Color%s=%.2x%.2x%.2x', [Chr(Ord('A') + (I - 1)), R, G, B]));
  end;

  CLUT_COLOR := GetCLUTColor(TIM, CLUT_NUM, SELECTED_CELL);
  R := CLUT_COLOR.R;
  G := CLUT_COLOR.G;
  B := CLUT_COLOR.B;
  dlgColor.Color := RGB(R, G, B);

  if not dlgColor.Execute then
  begin
    FreeTIM(TIM);
    Exit;
  end;

  DIALOG_COLOR := dlgColor.Color;

  CLUT_COLOR.R := ((GetRValue(DIALOG_COLOR) div 8) and $1F) * 8;
  CLUT_COLOR.G := ((GetGValue(DIALOG_COLOR) div 8) and $1F) * 8;
  CLUT_COLOR.B := ((GetBValue(DIALOG_COLOR) div 8) and $1F) * 8;

  WriteCLUTColor(TIM, CLUT_NUM, SELECTED_CELL, CLUT_COLOR);

  ReplaceTimInFileFromMemory(ScanRes.ScanFile, TIM, TimIdx(ListIdx).Position, ScanRes.IsImage);

  FreeTIM(TIM);

  DrawSelTim;
  DrawSelClut;
end;

procedure TfrmMain.grdCurrClutDrawCell(Sender: TObject; ACol, ARow: Integer;
  Rect: TRect; State: TGridDrawState);
var
  TIM: PTIM;
begin
  TIM := SelTim;
  if TIM = nil then Exit;

  if not TIMHasCLUT(TIM) then
  begin
    FreeTIM(TIM);
    Exit;
  end;

  DrawClutCell(TIM, cbbCLUT.ItemIndex, @grdCurrCLUT, ACol, ARow);

  FreeTIM(TIM);
end;

function TfrmMain.ListIdx: Integer;
begin
  Result := lvList.Selected.Index;
end;

procedure TfrmMain.ScanDirectory(const Directory: string);
var
  sRec: TSearchRec;
  isFound: boolean;
  Dir: string;
begin
  Dir := IncludeTrailingPathDelimiter(Directory);
  isFound := FindFirst(Dir + '*', faAnyFile, sRec) = 0;
  while isFound do
  begin
    if (sRec.Name <> '.') and (sRec.Name <> '..') then
    begin
      if (sRec.Attr and faDirectory) = faDirectory then
        ScanDirectory(Dir + sRec.Name)
      else
        ScanFile(Dir + sRec.Name);
    end;
    Application.ProcessMessages;
    isFound := FindNext(sRec) = 0;
  end;
  FindClose(sRec);
end;

procedure TfrmMain.lvListChange(Sender: TObject; Item: TListItem;
  Change: TItemChange);
begin
  if (Item = nil) or (Change <> ctState) then Exit;

  if Item.Focused and Item.Selected then
    ShowItem;
end;

procedure TfrmMain.lvListData(Sender: TObject; Item: TListItem);
var
  W, H: Word;
begin
  if cbbFiles.ItemIndex = -1 then Exit;

  W := TimIdx(Item.Index).Width;
  H := TimIdx(Item.Index).Height;

  Item.Caption := Format('%.6d', [Item.Index + 1]);
  Item.SubItems.Add(Format('%.3dx%.3d', [W, H]));
  Item.SubItems.Add(Format('%.2d', [TimIdx(Item.Index).BitMode]));
  Item.SubItems.Add(Format('%.2d', [TimIdx(Item.Index).Cluts]));
end;

procedure TfrmMain.SetListCount(Count: Integer);
begin
  lvList.Items.BeginUpdate;
  lvList.Items.Count := Count;
  lvList.Column[0].Caption := Format('# / %d', [Count]);
  lvList.Items.EndUpdate;
end;

procedure TfrmMain.ShowItem;
begin
  if (lvList.Selected = nil) then Exit;
  if (lvList.Items.Count = 0) then Exit;

  cbbBitMode.ItemIndex := 0;

  UpdateCLUTInfo;
  DrawSelTim;
  DrawSelClut;

  actTimInfo.Caption := Format('[OFFSET: 0x%x | SIZE: 0x%x]', [TimIdx(ListIdx).Position, TimIdx(ListIdx).Size]);
  actTimInfo.Enabled := True;

  CheckButtonsAndMainMenu;
end;

function TfrmMain.TimIdx(Index: Integer): TScanTim;
begin
  Result := ScanRes.ScanTim[Index];
end;

procedure TfrmMain.ScanFile(const FileName: string);
begin
  if CheckForFileOpened(FileName) then
  begin
    cbbFiles.ItemIndex := cbbFiles.Items.IndexOf(FileName);
    btnStopScan.Enabled := False;
    btnStopScan.Tag := NativeInt(True);
    CheckButtonsAndMainMenu;
    Exit;
  end;

  if not Boolean(btnStopScan.Tag) then
  begin
    ScanThreads.Add(TScanThread.Create(FileName, GetImageScan(FileName)));
    ScanThreads.Last.FreeOnTerminate := True;
    ScanThreads.Last.Priority := tpNormal;
    ScanThreads.Last.OnTerminate := ScanFinished;

    if StartedScans < GetCoreCount then
    begin
      ScanThreads.Last.Start;
      Inc(StartedScans);
    end;
  end;
end;

procedure TfrmMain.ScanFinished(Sender: TObject);
var
  I: Integer;
begin
  ScanThreads.Remove(Sender as TScanThread);
  Dec(StartedScans);

  if ScanThreads.Count <> 0 then
  begin
    for I := 1 to ScanThreads.Count do
      if ScanThreads[I - 1].Suspended and (not ScanThreads[I - 1].StopScan) then
      begin
        ScanThreads[I - 1].Start;
        Inc(StartedScans);
        Exit;
      end;
    Exit;
  end;

  if ScanResult.Count <> 0 then SetListCount(ScanResult.Last.Count);

  CheckButtonsAndMainMenu;

  if cbbFiles.Enabled then
  begin
    cbbFiles.ItemIndex := cbbFiles.Items.Count - 1;
    cbbFilesChange(Self);
  end;

  btnStopScan.Enabled := False;
  btnStopScan.Tag := NativeInt(True);
end;

procedure TfrmMain.ScanPath(const Path: string);
begin
  if Path = '' then Exit;

  btnStopScan.Enabled := True;
  btnStopScan.Tag := NativeInt(False);

  if CheckFileExists(Path) then
    ScanFile(Path)
  else
    ScanDirectory(Path);
end;

procedure TfrmMain.SetCLUTListToNoCLUT;
var
  I: Integer;
begin
  if cbbCLUT.Items.Count > 0 then
  begin
    cbbCLUT.Items.BeginUpdate;

    for I := 0 to cbbCLUT.Items.Count - 2 do
      cbbCLUT.Items.Delete(I);

    cbbCLUT.Items[0] := sThisTimHasNoClut;

    cbbCLUT.Items.EndUpdate;
  end
  else
    cbbCLUT.Items.Add(sThisTimHasNoClut);

  cbbCLUT.ItemIndex := 0;
end;

procedure TfrmMain.UpdateCLUTInfo;
var
  TIM: PTIM;
  I, CLUTS: Word;
begin
  TIM := SelTim;
  if TIM = nil then Exit;

  CLUTS := GetTIMClutsCount(TIM);
  //cbbCLUT.Items.Clear;

  cbbCLUT.Items.BeginUpdate;
  for I := 0 to cbbCLUT.Items.Count -1 do
    cbbCLUT.Items[i] := Format('CLUT [%.2d/%.2d]', [I + 1, CLUTS]);

  for I := cbbCLUT.Items.Count + 1 to CLUTS do
    cbbCLUT.Items.Add(Format('CLUT [%.2d/%.2d]', [I, CLUTS]));
  cbbCLUT.Items.EndUpdate;

  if CLUTS = 0 then SetCLUTListToNoCLUT;

  cbbCLUT.ItemIndex := 0;

  FreeTIM(TIM);
end;

procedure TfrmMain.WMDropFiles(var Msg: TWMDropFiles);
var
  I: Integer;
  CountFile: Integer;
  SIZE: Integer;
  FileName: PChar;
begin
  FileName := nil;
  try
    CountFile := DragQueryFile(Msg.Drop, $FFFFFFFF, FileName, 1024);

    for I := 0 to (CountFile - 1) do
    begin
      SIZE := DragQueryFile(Msg.Drop, I, nil, 0) + 1;
      FileName := StrAlloc(SIZE);
      DragQueryFile(Msg.Drop, I, FileName, SIZE);
      ScanPath(StrPas(FileName));
      StrDispose(FileName);
    end;
  finally
    DragFinish(Msg.Drop);
  end;

end;

end.