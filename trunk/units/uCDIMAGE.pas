unit uCDIMAGE;

interface

uses
  Windows, uTIM;

const
  cSectorHeaderSize = 12;
  cSectorAddressSize = 3;
  cSectorModeSize = 1;
  cSectorSubHeaderSize = 8;
  cSectorInfoSize = cSectorHeaderSize + cSectorAddressSize + cSectorModeSize +
    cSectorSubHeaderSize;
  cSectorDataSize = 2048;
  cSectorECCSize = 4;
  cSectorEDCSize = 276;
  cSectorECCEDCSize = cSectorECCSize + cSectorEDCSize;
  cSectorSize = cSectorInfoSize + cSectorDataSize + cSectorECCEDCSize;

type
  TCDSector = packed record
    dwHeader: array[0..cSectorHeaderSize - 1] of byte;
    dwAddress: array[0..cSectorAddressSize - 1] of byte;
    bMode: Byte;
    dwSubHeader: array[0..cSectorSubHeaderSize - 1] of byte;
    dwData: array[0..cSectorDataSize - 1] of byte;
    dwECC: array[0..cSectorECCSize - 1] of byte;
    dwEDC: array[0..cSectorEDCSize - 1] of byte;
  end;
  PCDSector = ^TCDSector;

function GetImageScan(const FileName: string): Boolean;
function ReplaceTimInFile(const FileName, TimToInsert: string;
                          InsertTo: DWORD; ImageScan: Boolean): boolean;
procedure ReplaceTimInFileFromMemory(const FileName: string; TIM: PTIM;
                                     InsertTo: DWORD; ImageScan: Boolean);

implementation

uses
  uCommon, ecc, edc, System.SysUtils, System.Classes;

function bin2bcd(P: Integer): Byte;
begin
  Result := ((p div 10) shl 4) or (p mod 10);
end;

procedure BuildAdress(LBA: Integer; var Dest);
var
  P: PByte;
begin
  Inc(LBA, 75 * 2); // 2 seconds
  P := @Dest;
  P^ := bin2bcd(LBA div (60 * 75));
  Inc(P);
  P^ := bin2bcd((LBA div 75) mod 60);
  Inc(P);
  P^ := bin2bcd(LBA mod 75);
  Inc(P);
  P^ := 2;
end;

function GetImageScan(const FileName: string): Boolean;
const
  cSectorHeader: array[0..cSectorHeaderSize - 1] of byte = (
    $00, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $00);
var
  Sz: cardinal;
  pFile: PBytesArray;
  tmp: TFileStream;
begin
  Result := False;
  Sz := GetFileSizeAPI(FileName);

  if (Sz > cMaxFileSize) or (Sz = 0) then Exit;

  pFile := GetMemory(cSectorHeaderSize);
  tmp := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
  tmp.Read(pFile^[0], cSectorHeaderSize);
  result := ((Sz mod cSectorSize) = 0) and
    (CompareMem(@cSectorHeader, pFile, cSectorHeaderSize));
  tmp.free;
  FreeMemory(pFile);
end;

procedure ReplaceTimInFileFromMemory(const FileName: string;
                                    TIM: PTIM; InsertTo: DWORD;
                                    ImageScan: Boolean);
type
  TSecAddrAndMode = array[0..cSectorAddressSize + cSectorModeSize] of byte;
var
  sImageStream: TFileStream;
  TimOffsetInSector, FirstPartSize, LastPartSize: DWORD;
  TimSectorNumber, TimStartSectorPos: DWORD;
  Sector: TCDSector;
  ECC: DWORD;
  P, TIM_FULL_SECTORS: DWORD;
  SecAddrAndMode: TSecAddrAndMode;
begin
  sImageStream := TFileStream.Create(FileName, fmOpenReadWrite or
                                               fmShareDenyWrite);

  if not ImageScan then
  begin
    sImageStream.Seek(InsertTo, soBeginning);
    sImageStream.Write(TIM^.DATA^[0], TIM^.dwSIZE);
  end
  else
  begin
    P := 0;

    TimSectorNumber := InsertTo div cSectorSize + 1;
    TimOffsetInSector := InsertTo mod cSectorSize - cSectorInfoSize;
    TimStartSectorPos := (TimSectorNumber - 1) * cSectorSize;
    FirstPartSize := cSectorDataSize - TimOffsetInSector;

    if TIM^.dwSIZE < FirstPartSize then
    FirstPartSize := TIM^.dwSIZE;

    sImageStream.Seek(TimStartSectorPos, soBeginning);
    FillChar(Sector, SizeOf(Sector), 0);
    sImageStream.Read(Sector, cSectorSize);
    Move(Sector.dwAddress[0], SecAddrAndMode[0], cSectorAddressSize +
      cSectorModeSize);
    FillChar(Sector.dwAddress[0], cSectorAddressSize + cSectorModeSize, 0);

    Move(TIM^.DATA^[P], Sector.dwData[TimOffsetInSector], FirstPartSize);
    Inc(P, FirstPartSize);

    ECC := build_edc(@(Sector.dwSubHeader[0]), cSectorSubHeaderSize +
                     cSectorDataSize);
    Move(ECC, Sector.dwECC, cSectorECCSize);
    encode_L2_P(@(Sector.dwAddress[0]));
    encode_L2_Q(@(Sector.dwAddress[0]));
    BuildAdress(TimSectorNumber, Sector.dwAddress[0]);

    sImageStream.Seek(-cSectorSize + cSectorHeaderSize, soCurrent);
    sImageStream.Write(SecAddrAndMode[0], cSectorAddressSize + cSectorModeSize);

    Inc(TimStartSectorPos, cSectorSize);
    sImageStream.Seek(TimStartSectorPos, soBeginning);

    TIM_FULL_SECTORS := (TIM^.dwSIZE - P) div cSectorDataSize;

    while TIM_FULL_SECTORS > 0 do
    begin
      Inc(TimSectorNumber);

      sImageStream.Read(Sector, cSectorSize);
      Move(Sector.dwAddress[0], SecAddrAndMode[0], cSectorAddressSize +
        cSectorModeSize);
      FillChar(Sector.dwAddress[0], cSectorAddressSize + cSectorModeSize, 0);

      Move(TIM^.DATA^[P], Sector.dwData[0], cSectorDataSize);
      Inc(P, cSectorDataSize);

      ECC := build_edc(@(Sector.dwSubHeader[0]), cSectorSubHeaderSize +
        cSectorDataSize);
      Move(ECC, Sector.dwECC, cSectorECCSize);
      encode_L2_P(@(Sector.dwAddress[0]));
      encode_L2_Q(@(Sector.dwAddress[0]));
      BuildAdress(TimSectorNumber, Sector.dwAddress[0]);

      sImageStream.Seek(TimStartSectorPos + cSectorHeaderSize, soBeginning);
      sImageStream.Write(SecAddrAndMode[0], cSectorAddressSize + cSectorModeSize);

      Inc(TimStartSectorPos, cSectorSize);
      sImageStream.Seek(TimStartSectorPos, soBeginning);

      Dec(TIM_FULL_SECTORS);
    end;

    Inc(TimSectorNumber);

    sImageStream.Read(Sector, cSectorSize);
    Move(Sector.dwAddress[0], SecAddrAndMode[0], cSectorAddressSize +
      cSectorModeSize);
    FillChar(Sector.dwAddress[0], cSectorAddressSize + cSectorModeSize, 0);

    if TIM^.dwSIZE > P then
    begin
      LastPartSize := TIM^.dwSIZE - P;
      Move(TIM^.DATA^[P], Sector.dwData[0], LastPartSize);

      ECC := build_edc(@(Sector.dwSubHeader[0]), cSectorSubHeaderSize +
                       cSectorDataSize);
      Move(ECC, Sector.dwECC, cSectorECCSize);
      encode_L2_P(@(Sector.dwAddress[0]));
      encode_L2_Q(@(Sector.dwAddress[0]));
      BuildAdress(TimSectorNumber, Sector.dwAddress[0]);

      sImageStream.Seek(TimStartSectorPos + cSectorHeaderSize, soBeginning);
      sImageStream.Write(SecAddrAndMode[0], cSectorAddressSize + cSectorModeSize);
    end;
  end;

  sImageStream.Free;
end;

function ReplaceTimInFile(const FileName, TimToInsert: string;
                          InsertTo: DWORD; ImageScan: Boolean): boolean;

var
  SIZE, P: DWORD;
  TIM: PTIM;
begin
  result := false;

  SIZE := GetFileSizeAPI(TimToInsert);
  P := 0;
  TIM := LoadTimFromFile(TimToInsert, P, False, SIZE);
  if TIM = nil then Exit;

  ReplaceTimInFileFromMemory(FileName, TIM, InsertTo, ImageScan);

  FreeTIM(TIM);
  result := True;
end;

end.

