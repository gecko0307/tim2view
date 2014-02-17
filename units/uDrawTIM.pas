unit uDrawTIM;

interface

uses
  Vcl.Graphics, uTIM, System.Types, Vcl.Imaging.pngimage, Vcl.Grids;

type
  PCanvas = ^TCanvas;
  PPNGImage = ^TPngImage;
  PDrawGrid = ^TDrawGrid;

procedure DrawTIM(TIM: PTIM; CLUT_NUM: Integer; ACanvas: PCanvas; Rect: TRect;
  var PNG: PPNGImage; TranspMode: Byte);
procedure TimToPNG(TIM: PTIM; CLUT_NUM: Integer; var PNG: PPNGImage;
  TranspMode: Byte);
procedure DrawPNG(PNG: PPNGImage; ACanvas: PCanvas; Rect: TRect);
procedure DrawClutCell(TIM: PTIM; CLUT_NUM: Integer; Grid: PDrawGrid;
  X, Y: Integer);
procedure DrawCLUT(TIM: PTIM; CLUT_NUM: Integer; Grid: PDrawGrid);
procedure ClearCanvas(CHandle: THandle; Rect: TRect);
procedure ClearGrid(Grid: PDrawGrid);

implementation

uses
  Windows, uCommon;

function PrepareCLUT(TIM: PTIM; CLUT_NUM: Integer): PCLUT_COLORS;
var
  I: Integer;
begin
  Result := nil;
  if (not TIMHasCLUT(TIM)) and (not(TIM^.HEAD^.bBPP in [cTIM4NC, cTIM8NC])) then
    Exit;

  New(Result);

  if (TIM^.HEAD^.bBPP in [cTIM4NC, cTIM8NC]) then
  begin
    Randomize;
    for I := 1 to cRandomPaletteSize do
      Result^[I - 1] := GetCLUTColor(TIM, CLUT_NUM, I - 1);

    Exit;
  end;

  for I := 1 to GetTimColorsCount(TIM) do
    Result^[I - 1] := GetCLUTColor(TIM, CLUT_NUM, I - 1);
end;

function PrepareIMAGE(TIM: PTIM): PIMAGE_INDEXES;
var
  I, OFFSET: Integer;
  RW: Word;
  P24: DWORD;
begin
  New(Result);
  OFFSET := cTIMHeadSize + GetTIMCLUTSize(TIM) + cIMAGEHeadSize;
  RW := GetTimRealWidth(TIM);

  case TIM^.HEAD^.bBPP of
    cTIM4C, cTIM4NC:
      for I := 1 to TIM^.IMAGE^.wWidth * TIM^.IMAGE^.wHeight * 2 do
      begin
        Result^[(I - 1) * 2] := TIM^.DATA^[OFFSET + I - 1] and $F;
        Result^[(I - 1) * 2 + 1] := (TIM^.DATA^[OFFSET + I - 1] and $F0) shr 4;
      end;

    cTIM8C, cTIM8NC:
      for I := 1 to TIM^.IMAGE^.wWidth * TIM^.IMAGE^.wHeight * 2 do
        Result^[I - 1] := TIM^.DATA^[OFFSET + I - 1];

    cTIM16C, cTIM16NC:
      for I := 1 to TIM^.IMAGE^.wWidth * TIM^.IMAGE^.wHeight do
        Move(TIM^.DATA^[OFFSET + (I - 1) * 2], Result^[I - 1], 2);

    cTIM24C, cTIM24NC:
      begin
        I := 1;
        P24 := 0;

        while I <= (TIM^.IMAGE^.wWidth * TIM^.IMAGE^.wHeight * 2) do
        begin
          Result^[P24] := 0;
          Move(TIM^.DATA^[OFFSET + (I - 1)], Result^[P24], 3);
          Inc(I, 3);

          if Odd(RW) and (((P24 + 1) mod RW) = 0) then
            Inc(OFFSET);

          Inc(P24);
        end;
      end;
  end;
end;

procedure TimToPNG(TIM: PTIM; CLUT_NUM: Integer; var PNG: PPNGImage;
  TranspMode: Byte);
var
  RW, RH, CW: Word;
  CLUT_DATA: PCLUT_COLORS;
  IMAGE_DATA: PIMAGE_INDEXES;
  X, Y, INDEX, IMAGE_DATA_POS: Integer;
  R, G, B, STP, ALPHA: Byte;
  COLOR: TCLUT_COLOR;
  CL: DWORD;
  Transparent, SemiTransparent: boolean;
begin
  RW := GetTimRealWidth(TIM);
  RH := GetTimHeight(TIM);

  PNG^ := TPngImage.CreateBlank(COLOR_RGBALPHA, 16, RW, RH);
  PNG^.CompressionLevel := 9;
  PNG^.Filters := [];

  CLUT_DATA := PrepareCLUT(TIM, CLUT_NUM);
  IMAGE_DATA := PrepareIMAGE(TIM);

  IMAGE_DATA_POS := 0;

  R := 0;
  G := 0;
  B := 0;
  STP := 0;

  Transparent := TranspMode in [0, 1];
  SemiTransparent := TranspMode in [0, 2];

  for Y := 1 to RH do
    for X := 1 to RW do
    begin
      case TIM^.HEAD^.bBPP of
        cTIM4C, cTIM4NC, cTIM8C, cTIM8NC:
          begin
            INDEX := IMAGE_DATA^[IMAGE_DATA_POS];

            R := CLUT_DATA^[INDEX].R;
            G := CLUT_DATA^[INDEX].G;
            B := CLUT_DATA^[INDEX].B;
            STP := CLUT_DATA^[INDEX].STP;
          end;
        cTIM16C, cTIM16NC, cTIMMix:
          begin
            Move(IMAGE_DATA^[IMAGE_DATA_POS], CW, 2);
            COLOR := ConvertTIMColor(CW);

            R := COLOR.R;
            G := COLOR.G;
            B := COLOR.B;
            STP := COLOR.STP;
          end;
        cTIM24C, cTIM24NC:
          begin
            CL := IMAGE_DATA^[IMAGE_DATA_POS];

            R := (CL and $FF);
            G := ((CL and $FF00) shr 8);
            B := ((CL and $FF0000) shr 16);
            STP := 0;
          end;
      else
        Break;
      end;

      if (TIM^.HEAD^.bBPP in cTIM24) or (not(Transparent or SemiTransparent))
      then
        ALPHA := 255
      else
      begin
        if (R + G + B) = 0 then
          ALPHA := 0
        else
        begin
          if (STP = 0) then
            ALPHA := 255
          else
            ALPHA := 128;

          if (not SemiTransparent) and (ALPHA = 128) then
            ALPHA := 255;
        end;
      end;

      PNG^.AlphaScanline[Y - 1]^[X - 1] := ALPHA;

      if ALPHA = 0 then
      begin
        B := 0;
        G := 0;
        R := 0;
      end;

      pRGBLine(PNG^.Scanline[Y - 1])^[X - 1].rgbtBlue := B;
      pRGBLine(PNG^.Scanline[Y - 1])^[X - 1].rgbtGreen := G;
      pRGBLine(PNG^.Scanline[Y - 1])^[X - 1].rgbtRed := R;

      Inc(IMAGE_DATA_POS);
    end;

  Dispose(CLUT_DATA);
  Dispose(IMAGE_DATA);
end;

procedure DrawTIM(TIM: PTIM; CLUT_NUM: Integer; ACanvas: PCanvas; Rect: TRect;
  var PNG: PPNGImage; TranspMode: Byte);
begin
  TimToPNG(TIM, CLUT_NUM, PNG, TranspMode);
  DrawPNG(PNG, ACanvas, Rect);
end;

procedure ClearCanvas(CHandle: THandle; Rect: TRect);
begin
  PatBlt(CHandle, Rect.Left, Rect.Top, Rect.Width, Rect.Height, WHITENESS);
end;

procedure ClearGrid(Grid: PDrawGrid);
var
  X, Y, W, H: Word;
begin
  W := Grid^.ColCount;
  H := Grid^.RowCount;

  for Y := 1 to H do
    for X := 1 to W do
      ClearCanvas(Grid^.Canvas.Handle, Grid^.CellRect(X - 1, Y - 1));
end;

procedure DrawPNG(PNG: PPNGImage; ACanvas: PCanvas; Rect: TRect);
begin
  if PNG^ = nil then
    Exit;

  Rect.Width := PNG^.Width;
  Rect.Height := PNG^.Height;

  PNG^.Draw(ACanvas^, Rect);
end;

procedure DrawClutCell(TIM: PTIM; CLUT_NUM: Integer; Grid: PDrawGrid;
  X, Y: Integer);
var
  CLUT_COLOR: PCLUT_COLOR;
  R, G, B, STP, ALPHA: Byte;
  Rect: TRect;
  COLS: Integer;
begin
  New(CLUT_COLOR);

  COLS := Min(GetTimColorsCount(TIM), cCLUTGridColsCount);
  CLUT_COLOR^ := GetCLUTColor(TIM, CLUT_NUM, Y * COLS + X);
  R := CLUT_COLOR^.R;
  G := CLUT_COLOR^.G;
  B := CLUT_COLOR^.B;
  STP := CLUT_COLOR^.STP;

  Rect := Grid^.CellRect(X, Y);

  ClearCanvas(Grid^.Canvas.Handle, Rect);
  Grid^.Canvas.Brush.COLOR := RGB(R, G, B);

  Grid^.Canvas.FillRect(Rect);

  if (R + G + B) = 0 then
    ALPHA := 0
  else
  begin
    if STP = 0 then
      ALPHA := 255
    else
      ALPHA := 128;
  end;

  if ALPHA in [0, 128] then
  begin
    Grid^.Canvas.Brush.COLOR := clWhite;
    if ALPHA = 0 then
      Rect.Height := Rect.Height div 2
    else
      Rect.Width := Rect.Width div 2;

    Grid^.Canvas.FillRect(Rect);
  end;

  Dispose(CLUT_COLOR);
end;

procedure DrawCLUT(TIM: PTIM; CLUT_NUM: Integer; Grid: PDrawGrid);
var
  X, Y, ROWS, COLS, COLORS: Integer;
begin
  COLORS := GetTimColorsCount(TIM);
  COLS := Min(COLORS, cCLUTGridColsCount);
  Grid^.ColCount := COLS;
  ROWS := COLORS div COLS;

  Grid^.RowCount := ROWS;

  for Y := 1 to ROWS do
    for X := 1 to COLS do
    begin
      ClearCanvas(Grid^.Canvas.Handle, Grid^.CellRect(X - 1, Y - 1));
      DrawClutCell(TIM, CLUT_NUM, Grid, X - 1, Y - 1);
    end;
end;

end.