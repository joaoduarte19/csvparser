# CSV Parser
CSV Parser for Delphi

## Samples
```delphi
uses
  System.SysUtils,
  CSVParser.Reader;

var
  LCSVReader: TCSVReader;
begin
  try
    LCSVReader := TCSVReader.Create;
    try
      LCSVReader.LoadFromFile('path_to_csv_file.csv');
      while not LCSVReader.Eof do
      try
        // Get field by index
        Writeln(LCSVReader.Field[0]);
        // Get field by name
        Writeln(LCSVReader.FieldByName['field_name']);
      finally
        LCSVReader.Next;
      end;
    finally
      LCSVReader.Free;
    end;
  except
    on E: Exception do
      Writeln(E.ClassName, ': ', E.Message);
  end;
end.
```
