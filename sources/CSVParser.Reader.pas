// ***************************************************************************
//
// CSVParser
//
// Copyright (c) 2020 João Antônio Duarte
//
// https://github.com/joaoduarte19/csvparser
//
// ***************************************************************************
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//
// *************************************************************************** }

unit CSVParser.Reader;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections;

type
  {$SCOPEDENUMS ON}
  TEncodingType = (AUTO_DETECT, ANSI, UTF8);

  ECSVParserException = class(Exception);

  TCSVReader = class
  private
    FFieldNames: TList<string>;
    FCSVFile: TStrings;
    FFileName: string;
    FRowDelimiter: string;
    FFirstDataRow: Integer;
    FEncodingType: TEncodingType;
    FTextQualifier: Char;
    FFieldDelimiter: Char;
    FRowNumber: Integer;
    FFieldNameRow: Integer;
    FCurrentRow: string;
    function GetField(Index: Integer): string;
    function GetFieldByName(Index: string): string;
    procedure SetRowNumber(const Value: Integer);
    function GetEncoding: TEncoding;
    function GetFields(const ARow: string): TArray<string>;
    function GetRowsCount: Integer;
    procedure LoadFieldNames;
    procedure AfterOpen;
    function GetFieldsCount: Integer;
    function GetFieldName(Index: Integer): string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Open;
    procedure Close;
    procedure LoadFromFile(const AFileName: string);
    procedure LoadFromStream(const AStream: TStream);

    function Bof: Boolean;
    procedure First;
    procedure Prior;
    procedure Next;
    procedure Last;
    function Eof: Boolean;
    function ContainsField(const AFieldName: string): Boolean;

    property FileName: string read FFileName write FFileName;
    property EncodingType: TEncodingType read FEncodingType write FEncodingType default TEncodingType.ANSI;
    property RowDelimiter: string read FRowDelimiter write FRowDelimiter;
    property FieldDelimiter: Char read FFieldDelimiter write FFieldDelimiter default ',';
    property TextQualifier: Char read FTextQualifier write FTextQualifier default #0;
    property FieldNameRow: Integer read FFieldNameRow write FFieldNameRow default 0;
    property FirstDataRow: Integer read FFirstDataRow write FFirstDataRow default 1;
    property Field[Index: Integer]: string read GetField;
    property FieldByName[Index: string]: string read GetFieldByName; default;
    property FieldName[Index: Integer]: string read GetFieldName;
    property FieldsCount: Integer read GetFieldsCount;
    property RowNumber: Integer read FRowNumber write SetRowNumber;
    property RowsCount: Integer read GetRowsCount;
    property CurrentRow: string read FCurrentRow;
  end;

implementation

uses
  System.IOUtils;

{ TCSVReader }

procedure TCSVReader.AfterOpen;
begin
  LoadFieldNames;
  SetRowNumber(FFirstDataRow);
end;

function TCSVReader.Bof: Boolean;
begin
  Result := FRowNumber < FFirstDataRow;
end;

procedure TCSVReader.Close;
begin
  FCSVFile.Clear;
  FFieldNames.Clear;
end;

function TCSVReader.ContainsField(const AFieldName: string): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 0 to Pred(FFieldNames.Count) do
  begin
    if SameText(AFieldName, FFieldNames[I]) then
    begin
      Exit(True);
    end;
  end;
end;

constructor TCSVReader.Create;
begin
  inherited;

  FFileName := '';
  FRowDelimiter := sLineBreak;
  FFieldNameRow := 0;
  FFirstDataRow := 1;
  FEncodingType := TEncodingType.AUTO_DETECT;
  FTextQualifier := #0;
  FFieldDelimiter := ',';
  FRowNumber := - 1;

  FCSVFile := TStringList.Create;
  FFieldNames := TList<string>.Create;
end;

destructor TCSVReader.Destroy;
begin
  FCSVFile.Free;
  FFieldNames.Free;
  inherited;
end;

function TCSVReader.Eof: Boolean;
begin
  Result := FRowNumber > (FCSVFile.Count - 1);
end;

procedure TCSVReader.First;
begin
  SetRowNumber(FFirstDataRow);
end;

function TCSVReader.GetEncoding: TEncoding;
begin
  case FEncodingType of
    TEncodingType.ANSI:
      Result := TEncoding.ANSI;
  else
    Result := TEncoding.UTF8;
  end;
end;

function TCSVReader.GetField(Index: Integer): string;
var
  LFields: TArray<string>;
begin
  LFields := GetFields(FCurrentRow);
  Result := LFields[Index];
end;

function TCSVReader.GetFieldByName(Index: string): string;
var
  LIndex: Integer;
  I: Integer;
begin
  LIndex := - 1;
  for I := 0 to Pred(FFieldNames.Count) do
  begin
    if SameText(Index, FFieldNames[I]) then
    begin
      LIndex := I;
      Break;
    end;
  end;

  if LIndex >= 0 then
    Result := GetField(LIndex)
  else
    raise ECSVParserException.CreateFmt('"%s" field not found', [Index]);
end;

function TCSVReader.GetFieldName(Index: Integer): string;
begin
  Result := FFieldNames[Index];
end;

function TCSVReader.GetFields(const ARow: string): TArray<string>;
var
  LFields: TList<string>;
  LRow: string;
  LRowPos: Integer;
  LField: string;
  LEndField: Integer;
begin
  SetLength(Result, 0);
  LFields := TList<string>.Create;
  try
    LRow := ARow;
    LRowPos := 1;
    while LRowPos <= LRow.Length do
    begin
      if LRow[LRowPos] = FTextQualifier then
      begin
        LEndField := LRow.IndexOf(FTextQualifier, LRowPos);
        if (LRowPos = LRow.Length) and (LEndField <= - 1) then
          LEndField := LRow.Length;

        LField := LRow.Substring(LRowPos, LEndField - LRowPos);
        LFields.Add(LField);
        LRowPos := LEndField + 2;
      end
      else if LRow[LRowPos] = FFieldDelimiter then
      begin
        if LRow[LRowPos + 1] = FTextQualifier then
        begin
          Inc(LRowPos)
        end
        else
        begin
          LEndField := LRow.IndexOf(FFieldDelimiter, LRowPos);
          if (LRowPos = LRow.Length) and (LEndField <= - 1) then
            LEndField := LRow.Length;

          LField := LRow.Substring(LRowPos, LEndField - LRowPos);
          LFields.Add(LField);
          LRowPos := LEndField + 1;
        end;
      end
      else
      begin
        Inc(LRowPos);
      end;
    end;
    Result := LFields.ToArray;
  finally
    LFields.Free;
  end;
end;

function TCSVReader.GetFieldsCount: Integer;
begin
  Result := FFieldNames.Count;
end;

procedure TCSVReader.Last;
begin
  SetRowNumber(FCSVFile.Count - 1);
end;

procedure TCSVReader.LoadFieldNames;
var
  LHeader: string;
begin
  if FCSVFile.Count = 0 then
    Exit;

  LHeader := FCSVFile[FFieldNameRow];
  FFieldNames.Clear;
  FFieldNames.AddRange(GetFields(LHeader));
end;

procedure TCSVReader.LoadFromFile(const AFileName: string);
begin
  FFileName := AFileName;
  Open;
end;

procedure TCSVReader.LoadFromStream(const AStream: TStream);
begin
  if FEncodingType = TEncodingType.AUTO_DETECT then
  begin
    try
      FCSVFile.LoadFromStream(AStream, TEncoding.UTF8);
    except
      FCSVFile.LoadFromStream(AStream, TEncoding.ANSI);
    end
  end
  else
  begin
    FCSVFile.LoadFromStream(AStream, GetEncoding);
  end;

  AfterOpen;
end;

procedure TCSVReader.Next;
begin
  Inc(FRowNumber);
  if not Eof then
    FCurrentRow := FCSVFile[FRowNumber]
  else
    FCurrentRow := '';
end;

procedure TCSVReader.Open;
begin
  if not TFile.Exists(FFileName) then
    raise ECSVParserException.Create('File not exists');

  FCSVFile.Clear;
  FCSVFile.LineBreak := FRowDelimiter;

  if FEncodingType = TEncodingType.AUTO_DETECT then
  begin
    try
      FCSVFile.LoadFromFile(FFileName, TEncoding.UTF8);
    except
      FCSVFile.LoadFromFile(FFileName, TEncoding.ANSI);
    end;
  end
  else
  begin
    FCSVFile.LoadFromFile(FFileName, GetEncoding);
  end;

  AfterOpen;
end;

procedure TCSVReader.Prior;
begin
  Dec(FRowNumber);
  if not Bof then
    FCurrentRow := FCSVFile[FRowNumber]
  else
    FCurrentRow := '';
end;

function TCSVReader.GetRowsCount: Integer;
begin
  Result := FCSVFile.Count - FFirstDataRow;
end;

procedure TCSVReader.SetRowNumber(const Value: Integer);
begin
  if (Value < FFirstDataRow) or (Value >= (FCSVFile.Count - 1)) then
    raise ECSVParserException.Create('Value out of range');

  FRowNumber := Value;
  FCurrentRow := FCSVFile[FRowNumber];
end;

end.
