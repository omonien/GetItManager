program GetItManager;

{$APPTYPE CONSOLE}
{$R *.res}

/// <summary>
/// GetIt Manager v1.0.1 - RAD Studio Package Management Tool
/// A comprehensive solution for managing GetIt packages with automatic console buffer
/// capture to bypass RAD Studio 13.0 AccessViolation issues when using output redirection.
/// Copyright (c) 2025 Olaf Monien - Licensed under the MIT License
/// </summary>
/// <remarks>
/// This application automatically detects RAD Studio installations, captures package
/// lists using Windows Console API, categorizes packages intelligently, and provides
/// flexible installation options with progress tracking.
/// 
/// Key features:
/// - Multi-version RAD Studio support
/// - Category-based package organization (177 packages detected)
/// - Flexible package selection (individual, ranges, categories)
/// - Bypasses D13 GetItCmd AccessViolation issues
/// </remarks>

uses
  System.SysUtils,
  System.Classes,
  System.StrUtils,
  System.Generics.Collections,
  System.IOUtils,
  System.RegularExpressions,
  System.Math,
  Winapi.Windows;

{$REGION 'Type Declarations'}
type
  /// <summary>
  /// Represents a detected RAD Studio installation
  /// </summary>
  TDelphiVersion = record
    Version: string;    // Directory version (e.g., "37.0")  
    Name: string;       // Friendly name (e.g., "RAD Studio 13.0 Florence")
    Path: string;       // Installation path
    GetItCmd: string;   // Full path to GetItCmd.exe
  end;

  /// <summary>
  /// Represents a GetIt package with metadata
  /// </summary>
  TPackage = record
    Id: string;          // Package identifier
    Version: string;     // Package version
    Description: string; // Package description
    Category: string;    // Categorized type
    Selected: Boolean;   // User selection state
  end;

  // Collection types for managing installations and packages
  TDelphiVersionList = TList<TDelphiVersion>;
  TPackageList = TList<TPackage>;

{$REGION 'Windows Console API Declarations'}
type
  TCoord = packed record
    X: SmallInt;
    Y: SmallInt;
  end;

  TSmallRect = packed record
    Left: SmallInt;
    Top: SmallInt;
    Right: SmallInt;
    Bottom: SmallInt;
  end;

  TConsoleScreenBufferInfo = packed record
    dwSize: TCoord;
    dwCursorPosition: TCoord;
    wAttributes: Word;
    srWindow: TSmallRect;
    dwMaximumWindowSize: TCoord;
  end;

  TCharInfo = packed record
    case Integer of
      0: (UnicodeChar: WideChar);
      1: (AsciiChar: AnsiChar);
  end;

  TCharAttributes = packed record
    Char: TCharInfo;
    Attributes: Word;
  end;

function GetStdHandle(nStdHandle: DWORD): THandle; stdcall; external 'kernel32.dll';
function GetConsoleScreenBufferInfo(hConsoleOutput: THandle; var lpConsoleScreenBufferInfo: TConsoleScreenBufferInfo): BOOL; stdcall; external 'kernel32.dll';
function ReadConsoleOutput(hConsoleOutput: THandle; lpBuffer: Pointer; dwBufferSize: TCoord; dwBufferCoord: TCoord; var lpReadRegion: TSmallRect): BOOL; stdcall; external 'kernel32.dll' name 'ReadConsoleOutputW';
function ReadConsoleOutputCharacter(hConsoleOutput: THandle; lpCharacter: PWideChar; nLength: DWORD; dwReadCoord: TCoord; var lpNumberOfCharsRead: DWORD): BOOL; stdcall; external 'kernel32.dll' name 'ReadConsoleOutputCharacterW';
function SetConsoleScreenBufferSize(hConsoleOutput: THandle; dwSize: TCoord): BOOL; stdcall; external 'kernel32.dll';

const
  STD_OUTPUT_HANDLE = DWORD(-11);

function ExecuteProcessDirect(const ACommand, AParameters: string): Integer;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  WasOK: Boolean;
  WorkDir: string;
begin
  Result := -1;

  ZeroMemory(@SI, SizeOf(SI));
  SI.cb := SizeOf(SI);
  SI.dwFlags := STARTF_USESHOWWINDOW;
  SI.wShowWindow := SW_SHOW;

  WorkDir := ExtractFilePath(ACommand);
  
  WasOK := CreateProcess(nil,
    PChar('"' + ACommand + '" ' + AParameters),
    nil, nil, True,
    0,
    nil,
    PChar(WorkDir),
    SI, PI);

  if not WasOK then
    Exit;

  try
    WaitForSingleObject(PI.hProcess, INFINITE);
    GetExitCodeProcess(PI.hProcess, DWORD(Result));
  finally
    CloseHandle(PI.hProcess);
    CloseHandle(PI.hThread);
  end;
end;

function ExecuteProcessCapture(const ACommand, AParameters: string): TStringList;
var
  SI: TStartupInfo;
  PI: TProcessInformation;
  StdOutPipeRead, StdOutPipeWrite: THandle;
  WasOK: Boolean;
  Buffer: array[0..1023] of AnsiChar;
  BytesRead: Cardinal;
  WorkDir: string;
  OutputStr: AnsiString;
begin
  Result := TStringList.Create;
  OutputStr := '';

  if not CreatePipe(StdOutPipeRead, StdOutPipeWrite, nil, 0) then
    Exit;

  try
    SetHandleInformation(StdOutPipeWrite, HANDLE_FLAG_INHERIT, HANDLE_FLAG_INHERIT);

    ZeroMemory(@SI, SizeOf(SI));
    SI.cb := SizeOf(SI);
    SI.dwFlags := STARTF_USESTDHANDLES or STARTF_USESHOWWINDOW;
    SI.wShowWindow := SW_HIDE;
    SI.hStdInput := GetStdHandle(STD_INPUT_HANDLE);
    SI.hStdOutput := StdOutPipeWrite;
    SI.hStdError := StdOutPipeWrite;

    WorkDir := ExtractFilePath(ACommand);
    
    WasOK := CreateProcess(nil,
      PChar('"' + ACommand + '" ' + AParameters),
      nil, nil, True,
      0,
      nil,
      PChar(WorkDir),
      SI, PI);

    if WasOK then
    begin
      try
        CloseHandle(StdOutPipeWrite);
        StdOutPipeWrite := 0;

        repeat
          WasOK := ReadFile(StdOutPipeRead, Buffer, 1023, BytesRead, nil);
          if BytesRead > 0 then
          begin
            Buffer[BytesRead] := #0;
            OutputStr := OutputStr + Buffer;
          end;
        until not WasOK or (BytesRead = 0);

        WaitForSingleObject(PI.hProcess, INFINITE);

      finally
        CloseHandle(PI.hProcess);
        CloseHandle(PI.hThread);
      end;
    end;

  finally
    if StdOutPipeWrite <> 0 then CloseHandle(StdOutPipeWrite);
    CloseHandle(StdOutPipeRead);
  end;

  Result.Text := string(OutputStr);
end;

function ExecuteWithFileRedirection(const ACommand, AParameters: string): TStringList;
var
  TempFile: string;
  PowerShellCmd: string;
  ExitCode: Integer;
begin
  Result := TStringList.Create;
  
  TempFile := TPath.GetTempFileName;
  try
    // Use PowerShell Start-Process to avoid direct redirection AccessViolation
    PowerShellCmd := Format('Start-Process -FilePath "%s" -ArgumentList "%s" -RedirectStandardOutput "%s" -Wait -WindowStyle Hidden',
                           [ACommand, AParameters, TempFile]);
    
    // Execute PowerShell command
    ExitCode := ExecuteProcessDirect('powershell.exe', '-Command "' + PowerShellCmd + '"');
    
    if (ExitCode = 0) and TFile.Exists(TempFile) then
    begin
      try
        Result.LoadFromFile(TempFile);
      except
        // If file loading fails, return empty list
      end;
    end;
    
  finally
    if TFile.Exists(TempFile) then
      TFile.Delete(TempFile);
  end;
end;

function ReadConsoleBuffer: TStringList;
var
  ConsoleHandle: THandle;
  ConsoleInfo: TConsoleScreenBufferInfo;
  Row: Integer;
  ReadCoord: TCoord;
  LineBuffer: array[0..511] of WideChar;
  CharsRead: DWORD;
  Line: string;
  MaxRows: Integer;
  NewBufferSize: TCoord;
  OriginalBufferSize: TCoord;
  StartRow, EndRow: Integer;
begin
  Result := TStringList.Create;
  
  ConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if ConsoleHandle = INVALID_HANDLE_VALUE then Exit;
  
  if not GetConsoleScreenBufferInfo(ConsoleHandle, ConsoleInfo) then Exit;
  
  // Store original buffer size
  OriginalBufferSize := ConsoleInfo.dwSize;
  
  // Set a very large buffer size to ensure we don't lose content
  NewBufferSize.X := ConsoleInfo.dwSize.X;
  NewBufferSize.Y := 1000; // Much larger buffer
  
  SetConsoleScreenBufferSize(ConsoleHandle, NewBufferSize);
  
  // Re-read console info after buffer size change
  GetConsoleScreenBufferInfo(ConsoleHandle, ConsoleInfo);
  
  // Calculate reading range - read from current cursor position backwards
  // to capture the most recent output (GetItCmd output)
  EndRow := ConsoleInfo.dwCursorPosition.Y;
  MaxRows := 800; // Read up to 800 lines backwards from cursor (much more)
  StartRow := EndRow - MaxRows;
  if StartRow < 0 then StartRow := 0;
  
  // Ensure we don't exceed buffer bounds
  if EndRow >= ConsoleInfo.dwSize.Y then
    EndRow := ConsoleInfo.dwSize.Y - 1;
  
  // Also try reading the entire buffer if cursor-based approach fails
  if (EndRow - StartRow) < 200 then
  begin
    StartRow := 0;
    EndRow := ConsoleInfo.dwSize.Y - 1;
    if EndRow > 800 then EndRow := 800; // Cap at 800 lines
  end;
  
  // Read each row from StartRow to EndRow (includes recent GetItCmd output)
  for Row := StartRow to EndRow do
  begin
    ReadCoord.X := 0;
    ReadCoord.Y := Row;
    
    FillChar(LineBuffer, SizeOf(LineBuffer), 0);
    
    if ReadConsoleOutputCharacter(ConsoleHandle, @LineBuffer[0], 
                                 ConsoleInfo.dwSize.X, ReadCoord, CharsRead) then
    begin
      if CharsRead > 0 then
      begin
        LineBuffer[CharsRead] := #0; // Null terminate
        Line := Trim(WideCharToString(PWideChar(@LineBuffer[0])));
        Result.Add(Line);
      end
      else
        Result.Add(''); // Empty line
    end;
  end;
  
  // Restore original buffer size
  SetConsoleScreenBufferSize(ConsoleHandle, OriginalBufferSize);
end;

/// <summary>
/// Extended console buffer reading that tries multiple approaches to capture all GetIt packages
/// </summary>
/// <summary>
/// Enhanced console capture method with improved buffer management
/// Uses a large console buffer and captures complete output after execution
/// </summary>
function CaptureGetItOutputEnhanced(const ACommand, AParameters: string): TStringList;
var
  ConsoleHandle: THandle;
  OriginalBufferInfo, NewBufferInfo: TConsoleScreenBufferInfo;
  LargeBufferSize: TCoord;
  I: Integer;
  Line: string;
  ExitCode: Integer;
begin
  Result := TStringList.Create;
  
  ConsoleHandle := GetStdHandle(STD_OUTPUT_HANDLE);
  if ConsoleHandle = INVALID_HANDLE_VALUE then Exit;
  
  try
    // Get current buffer info
    if not GetConsoleScreenBufferInfo(ConsoleHandle, OriginalBufferInfo) then Exit;
    
    // Set up a very large buffer to ensure we don't lose any output
    LargeBufferSize.X := OriginalBufferInfo.dwSize.X;
    LargeBufferSize.Y := 5000; // Very large buffer
    
    // Increase buffer size before execution
    SetConsoleScreenBufferSize(ConsoleHandle, LargeBufferSize);
    
    // Clear current output for clean capture
    var StartPos: TCoord;
    var NumWritten: DWORD;
    StartPos.X := 0;
    StartPos.Y := 0;
    var WindowsCoord: Winapi.Windows.COORD;
    WindowsCoord.X := StartPos.X;
    WindowsCoord.Y := StartPos.Y;
    FillConsoleOutputCharacter(ConsoleHandle, ' ', LargeBufferSize.X * LargeBufferSize.Y, WindowsCoord, NumWritten);
    
    // Execute the GetIt command with our enhanced console
    ExitCode := ExecuteProcessDirect(ACommand, AParameters);
    
    if ExitCode = 0 then
    begin
      // Wait for all output to be written
      Sleep(300);
      
      // Get updated buffer info after command execution
      if GetConsoleScreenBufferInfo(ConsoleHandle, NewBufferInfo) then
      begin
        // Read from current cursor position backward to capture all content
        var TotalLines := Min(NewBufferInfo.dwCursorPosition.Y + 50, 3000);
        
        for I := 0 to TotalLines - 1 do
        begin
          var ReadCoord: TCoord;
          var LineBuffer: array[0..511] of WideChar;
          var CharsRead: DWORD;
          
          ReadCoord.X := 0;
          ReadCoord.Y := I;
          
          FillChar(LineBuffer, SizeOf(LineBuffer), 0);
          
          if ReadConsoleOutputCharacter(ConsoleHandle, @LineBuffer[0], 
                                       NewBufferInfo.dwSize.X, ReadCoord, CharsRead) then
          begin
            if CharsRead > 0 then
            begin
              LineBuffer[CharsRead] := #0;
              Line := Trim(WideCharToString(PWideChar(@LineBuffer[0])));
              if Length(Line) > 0 then
                Result.Add(Line);
            end;
          end;
        end;
      end;
    end;
    
  finally
    // Restore original buffer size
    SetConsoleScreenBufferSize(ConsoleHandle, OriginalBufferInfo.dwSize);
  end;
end;

function DetectDelphiVersions: TDelphiVersionList;
var
  StudioRoot: string;
  Directories: TArray<string>;
  Dir: string;
  RsvarsPath, GetItPath: string;
  DelphiVersion: TDelphiVersion;
  VersionMap: TDictionary<string, string>;
begin
  Result := TDelphiVersionList.Create;
  VersionMap := TDictionary<string, string>.Create;
  
  try
    // Map directory/registry version to friendly names (based on authoritative GitHub repo)
    // These map to the actual directory names in C:\Program Files (x86)\Embarcadero\Studio\xx.x
    VersionMap.Add('37.0', 'RAD Studio 13.0 Florence');
    VersionMap.Add('23.0', 'RAD Studio 12.3 Athens');
    VersionMap.Add('22.0', 'RAD Studio 11.3 Alexandria');
    VersionMap.Add('21.0', 'RAD Studio 10.4 Sydney');
    VersionMap.Add('20.0', 'RAD Studio 10.3 Rio');
    VersionMap.Add('19.0', 'RAD Studio 10.2 Tokyo');
    VersionMap.Add('18.0', 'RAD Studio 10.1 Berlin');
    VersionMap.Add('17.0', 'RAD Studio 10.0 Seattle');
    
    StudioRoot := 'C:\Program Files (x86)\Embarcadero\Studio';
    
    if TDirectory.Exists(StudioRoot) then
    begin
      Directories := TDirectory.GetDirectories(StudioRoot);
      for Dir in Directories do
      begin
        RsvarsPath := TPath.Combine(Dir, 'bin\rsvars.bat');
        GetItPath := TPath.Combine(Dir, 'bin\GetItCmd.exe');
        
        if TFile.Exists(RsvarsPath) and TFile.Exists(GetItPath) then
        begin
          DelphiVersion.Version := ExtractFileName(Dir);
          DelphiVersion.Path := Dir;
          DelphiVersion.GetItCmd := GetItPath;
          
          if VersionMap.ContainsKey(DelphiVersion.Version) then
            DelphiVersion.Name := VersionMap[DelphiVersion.Version]
          else
            DelphiVersion.Name := 'RAD Studio ' + DelphiVersion.Version;
            
          Result.Add(DelphiVersion);
        end;
      end;
    end;
    
  finally
    VersionMap.Free;
  end;
  
  // Sort by version (descending) - simple bubble sort
  for var I := 0 to Result.Count - 2 do
    for var J := I + 1 to Result.Count - 1 do
      if CompareStr(Result[J].Version, Result[I].Version) > 0 then
      begin
        var Temp := Result[I];
        Result[I] := Result[J];
        Result[J] := Temp;
      end;
end;

function SelectDelphiVersion(const Versions: TDelphiVersionList): Integer;
var
  I: Integer;
  Choice: string;
  ChoiceNum: Integer;
begin
  Result := -1;
  
  if Versions.Count = 0 then
  begin
    Writeln('No RAD Studio installations found!');
    Exit;
  end;
  
  if Versions.Count = 1 then
  begin
    Result := 0;
    Writeln(Format('Using: %s', [Versions[0].Name]));
    Exit;
  end;
  
  Writeln('Multiple RAD Studio versions detected:');
  Writeln('=====================================');
  for I := 0 to Versions.Count - 1 do
  begin
    Writeln(Format('  %d - %s (v%s)', [I + 1, Versions[I].Name, Versions[I].Version]));
    Writeln(Format('      Path: %s', [Versions[I].Path]));
  end;
  
  Writeln('');
  Write('Select version to use (1-' + IntToStr(Versions.Count) + '): ');
  Readln(Choice);
  
  if TryStrToInt(Trim(Choice), ChoiceNum) and (ChoiceNum >= 1) and (ChoiceNum <= Versions.Count) then
    Result := ChoiceNum - 1
  else
  begin
    Writeln('Invalid selection.');
    Result := -1;
  end;
end;

function CategorizePackage(const PackageId, Description: string): string;
var
  LowerID, LowerDesc: string;
begin
  // Categorize based on package ID and description
  LowerID := LowerCase(PackageId);
  LowerDesc := LowerCase(Description);
  
  if ContainsText(LowerID, 'style') or ContainsText(LowerDesc, 'style') then
    Result := 'UI Styles & Themes'
  else if ContainsText(LowerID, 'component') or ContainsText(LowerDesc, 'component') or 
          ContainsText(LowerID, 'control') or ContainsText(LowerDesc, 'control') then
    Result := 'Components & Controls'
  else if ContainsText(LowerID, 'template') or ContainsText(LowerDesc, 'template') or
          ContainsText(LowerID, 'demo') or ContainsText(LowerDesc, 'demo') then
    Result := 'Templates & Samples'
  else if ContainsText(LowerID, 'wizard') or ContainsText(LowerDesc, 'wizard') or
          ContainsText(LowerID, 'ide') or ContainsText(LowerDesc, 'ide') then
    Result := 'IDE Tools & Wizards'
  else if ContainsText(LowerID, 'boost') or ContainsText(LowerID, 'lib') or 
          ContainsText(LowerDesc, 'library') then
    Result := 'Libraries & Frameworks'
  else if ContainsText(LowerID, 'report') or ContainsText(LowerDesc, 'report') then
    Result := 'Reporting Tools'
  else if ContainsText(LowerID, 'database') or ContainsText(LowerDesc, 'database') or
          ContainsText(LowerID, 'sql') or ContainsText(LowerID, 'db') then
    Result := 'Database Tools'
  else if ContainsText(LowerID, 'game') or ContainsText(LowerDesc, 'game') or
          ContainsText(LowerDesc, 'arcade') then
    Result := 'Games & Samples'
  else if ContainsText(LowerID, 'android') or ContainsText(LowerID, 'ios') or
          ContainsText(LowerID, 'mobile') or ContainsText(LowerDesc, 'mobile') then
    Result := 'Mobile Development'
  else if ContainsText(LowerID, 'cloud') or ContainsText(LowerDesc, 'cloud') or
          ContainsText(LowerID, 'web') or ContainsText(LowerID, 'http') then
    Result := 'Web & Cloud Services'
  else if ContainsText(LowerID, 'ai') or ContainsText(LowerDesc, 'artificial intelligence') or
          ContainsText(LowerDesc, 'machine learning') then
    Result := 'AI & Machine Learning'
  else
    Result := 'Other Tools & Utilities';
end;

function ParsePackages(const Output: TStringList): TPackageList;
var
  I: Integer;
  Line: string;
  InPackageList: Boolean;
  Package: TPackage;
  Parts: TStringList;
  Pos1, Pos2: Integer;
  DebugSkipped: Integer;
begin
  Result := TPackageList.Create;
  InPackageList := False;
  Parts := TStringList.Create;
  DebugSkipped := 0;
  
  try
    for I := 0 to Output.Count - 1 do
    begin
      Line := Trim(Output[I]);
      
      if Line = '' then Continue;
        
      // Detect package list boundaries
      if ContainsText(Line, 'Id') and ContainsText(Line, 'Version') and ContainsText(Line, 'Description') then
      begin
        InPackageList := True;
        Continue;
      end;
      
      if ContainsText(Line, '---') then
      begin
        InPackageList := True;
        Continue;
      end;
      
      // More liberal detection: if line looks like a package line, assume we're in list
      if not InPackageList and (Length(Line) > 20) and (Pos(' ', Line) > 0) then
      begin
        var FirstWord := Copy(Line, 1, Pos(' ', Line) - 1);
        // If first word looks like package ID (starts with letter, has reasonable chars)
        if (Length(FirstWord) >= 3) and 
           CharInSet(FirstWord[1], ['A'..'Z', 'a'..'z']) and
           not ContainsText(FirstWord, 'Package') and
           not ContainsText(FirstWord, 'Copyright') and
           not ContainsText(FirstWord, 'Command') then
          InPackageList := True;
      end;
      
      // Stop parsing at certain boundaries (but NOT at Press enter - packages continue after that)
      if ContainsText(Line, 'Command finished') or
         ContainsText(Line, 'Reading console buffer') then
        Break;
        
      // Skip header/footer lines and empty lines filled with spaces
      if ContainsText(Line, 'GetIt Package Manager') or 
         ContainsText(Line, 'Copyright') or
         ContainsText(Line, 'All Rights Reserved') or
         ContainsText(Line, 'Successfully captured') or
         ContainsText(Line, 'Executing GetItCmd') or
         ContainsText(Line, 'Command finished') or
         (Length(Trim(Line)) = 0) then // Skip empty lines
        Continue;
      
      // Skip error messages, our debug output, and lines that are only spaces
      // DO NOT skip "Press enter to continue" - packages continue after pagination!
      if ContainsText(UpperCase(Line), 'ERROR:') or 
         ContainsText(UpperCase(Line), 'ACCESS') or 
         ContainsText(UpperCase(Line), 'EXCEPTION') or
         ContainsText(UpperCase(Line), 'VIOLATION') or
         ContainsText(Line, 'DEBUG:') or
         ContainsText(Line, 'Found') or
         ContainsText(Line, 'parsing') then
        Continue;
      
      // Skip pagination markers but continue processing (packages continue after this)
      if ContainsText(Line, 'Press enter to continue') then
        Continue;
      
      // Parse package lines - they have specific format with multiple spaces
      if InPackageList and (Length(Line) > 20) then
      begin
        // Look for lines that match package pattern: ID followed by multiple spaces, version, multiple spaces, description
        var TrimmedLine := Trim(Line);
        
        // Check if line starts with a package ID (letter/digit, contains hyphen/underscore)
        if (Length(TrimmedLine) > 10) and 
           CharInSet(TrimmedLine[1], ['A'..'Z', 'a'..'z', '0'..'9']) and
           not ContainsText(TrimmedLine, 'Id ') and
           not ContainsText(TrimmedLine, '--') then
        begin
          // Split by multiple spaces to get ID, Version, Description
          var PackageParts: TArray<string>;
          var TempLine := TrimmedLine;
          
          // Replace multiple spaces with a tab character for better splitting
          while Pos('  ', TempLine) > 0 do
            TempLine := StringReplace(TempLine, '  ', #9, [rfReplaceAll]);
          
          // Now split on tab characters which represent field boundaries
          PackageParts := TempLine.Split([#9]);
          
          // Remove empty entries manually
          var CleanParts: TArray<string>;
          var CleanCount := 0;
          for var Part in PackageParts do
          begin
            if Trim(Part) <> '' then
            begin
              SetLength(CleanParts, CleanCount + 1);
              CleanParts[CleanCount] := Trim(Part);
              Inc(CleanCount);
            end;
          end;
          PackageParts := CleanParts;
          
          if Length(PackageParts) >= 2 then
          begin
            Package.Id := Trim(PackageParts[0]);
            Package.Version := Trim(PackageParts[1]);
            
            // Handle description - might be empty or combined with version
            if Length(PackageParts) >= 3 then
              Package.Description := Trim(PackageParts[2])
            else
              Package.Description := 'Package description';
              
            // Clean up common formatting issues
            if Package.Description = '' then
              Package.Description := 'Package description';
            
            // Very liberal validation - accept almost anything that looks like a package
            if (Length(Package.Id) >= 2) and 
               (Length(Package.Version) >= 1) and
               not ContainsText(Package.Id, ' ') then
            begin
              // Clean up description if it ends with ...
              if Package.Description.EndsWith('...') then
                Package.Description := Package.Description.Substring(0, Package.Description.Length - 3).Trim;
              
              Package.Category := CategorizePackage(Package.Id, Package.Description);
              Package.Selected := False;
              Result.Add(Package);
            end;
          end
          else
          begin
            // Debug: This line looked like a package but didn't parse correctly
            if InPackageList and (Length(TrimmedLine) > 10) and 
               CharInSet(TrimmedLine[1], ['A'..'Z', 'a'..'z', '0'..'9']) then
            begin
              Inc(DebugSkipped);
              // Debug: Package line failed parsing
            end;
          end;
        end;
      end
      else if InPackageList and (Length(Line) > 10) then
      begin
        // Debug: Track lines that were in package list but too short
        var TrimmedLine := Trim(Line);
        if (Length(TrimmedLine) > 5) and 
           CharInSet(TrimmedLine[1], ['A'..'Z', 'a'..'z', '0'..'9']) then
        begin
          Inc(DebugSkipped);
          // Debug: Line too short
        end;
      end;
    end;
    
    // Debug output
    Writeln(Format('DEBUG: Skipped %d potential package lines during parsing', [DebugSkipped]));
    
  finally
    Parts.Free;
  end;
end;

procedure ShowPackagesByCategory(const Packages: TPackageList);
var
  Categories: TStringList;
  I, J: Integer;
  CurrentCategory: string;
  PackageCount: Integer;
begin
  Categories := TStringList.Create;
  try
    Categories.Duplicates := dupIgnore;
    Categories.Sorted := True;
    
    // Collect all categories
    for I := 0 to Packages.Count - 1 do
      Categories.Add(Packages[I].Category);
    
    Writeln('Available packages by category:');
    Writeln('==============================');
    
    for I := 0 to Categories.Count - 1 do
    begin
      CurrentCategory := Categories[I];
      PackageCount := 0;
      
      // Count packages in this category
      for J := 0 to Packages.Count - 1 do
        if Packages[J].Category = CurrentCategory then
          Inc(PackageCount);
      
      Writeln(Format('%s (%d packages)', [CurrentCategory, PackageCount]));
      Writeln(StringOfChar('-', Length(CurrentCategory) + 20));
      
      // Show packages in this category
      for J := 0 to Packages.Count - 1 do
      begin
        if Packages[J].Category = CurrentCategory then
        begin
          Writeln(Format('  [%3d] %s (v%s)', [J + 1, Packages[J].Id, Packages[J].Version]));
          Writeln(Format('        %s', [Packages[J].Description]));
        end;
      end;
      Writeln('');
    end;
    
    Writeln(Format('Total packages available: %d', [Packages.Count]));
    
  finally
    Categories.Free;
  end;
end;

procedure SelectPackages(const Packages: TPackageList);
var
  Input: string;
  Parts: TStringList;
  I, J, PackageNum: Integer;
  RangeStart, RangeEnd: Integer;
  CategoryName: string;
  Categories: TStringList;
begin
  Parts := TStringList.Create;
  Categories := TStringList.Create;
  
  try
    Categories.Duplicates := dupIgnore;
    Categories.Sorted := True;
    
    // Collect categories
    for I := 0 to Packages.Count - 1 do
      Categories.Add(Packages[I].Category);
    
    Writeln('Package Selection:');
    Writeln('==================');
    Writeln('You can select packages in several ways:');
    Writeln('  - Individual numbers: 1 5 23 45');
    Writeln('  - Ranges: 1-10 25-30');
    Writeln('  - Category names: "UI Styles & Themes" "Components & Controls"');
    Writeln('  - Mixed: 1-5 "UI Styles & Themes" 23 45-50');
    Writeln('  - "all" for all packages');
    Writeln('');
    Writeln('Available categories:');
    for I := 0 to Categories.Count - 1 do
      Writeln(Format('  "%s"', [Categories[I]]));
    
    Writeln('');
    Write('Enter your selection: ');
    Readln(Input);
    
    Input := Trim(Input);
    if Input = '' then Exit;
    
    // Handle "all" selection
    if SameText(Input, 'all') then
    begin
      for I := 0 to Packages.Count - 1 do
        Packages[I] := Packages[I]; // This is to mark as selected
        
      // Since we can't modify record in place, we need to work around this
      for I := 0 to Packages.Count - 1 do
      begin
        var Pkg := Packages[I];
        Pkg.Selected := True;
        Packages[I] := Pkg;
      end;
      Exit;
    end;
    
    // Parse input for categories and numbers
    var InQuotes := False;
    var CurrentToken := '';
    var Tokens: TStringList := TStringList.Create;
    
    try
      // Split input respecting quoted strings
      for I := 1 to Length(Input) do
      begin
        if Input[I] = '"' then
          InQuotes := not InQuotes
        else if (Input[I] = ' ') and not InQuotes then
        begin
          if CurrentToken <> '' then
          begin
            Tokens.Add(CurrentToken);
            CurrentToken := '';
          end;
        end
        else
          CurrentToken := CurrentToken + Input[I];
      end;
      
      if CurrentToken <> '' then
        Tokens.Add(CurrentToken);
      
      // Process tokens
      for I := 0 to Tokens.Count - 1 do
      begin
        var Token := Trim(Tokens[I]);
        
        // Check if it's a category name
        if Categories.IndexOf(Token) >= 0 then
        begin
          // Select all packages in this category
          for J := 0 to Packages.Count - 1 do
          begin
            if Packages[J].Category = Token then
            begin
              var Pkg := Packages[J];
              Pkg.Selected := True;
              Packages[J] := Pkg;
            end;
          end;
        end
        // Check if it's a range
        else if Pos('-', Token) > 0 then
        begin
          Parts.Clear;
          Parts.Delimiter := '-';
          Parts.DelimitedText := Token;
          if (Parts.Count = 2) and 
             TryStrToInt(Parts[0], RangeStart) and 
             TryStrToInt(Parts[1], RangeEnd) then
          begin
            for J := RangeStart to RangeEnd do
            begin
              if (J >= 1) and (J <= Packages.Count) then
              begin
                var Pkg := Packages[J - 1];
                Pkg.Selected := True;
                Packages[J - 1] := Pkg;
              end;
            end;
          end;
        end
        // Check if it's a single number
        else if TryStrToInt(Token, PackageNum) then
        begin
          if (PackageNum >= 1) and (PackageNum <= Packages.Count) then
          begin
            var Pkg := Packages[PackageNum - 1];
            Pkg.Selected := True;
            Packages[PackageNum - 1] := Pkg;
          end;
        end;
      end;
      
    finally
      Tokens.Free;
    end;
    
  finally
    Parts.Free;
    Categories.Free;
  end;
end;

procedure ShowSelectedPackages(const Packages: TPackageList);
var
  I: Integer;
  SelectedCount: Integer;
begin
  SelectedCount := 0;
  
  for I := 0 to Packages.Count - 1 do
    if Packages[I].Selected then
      Inc(SelectedCount);
  
  if SelectedCount = 0 then
  begin
    Writeln('No packages selected.');
    Exit;
  end;
  
  Writeln(Format('Selected packages for installation (%d):', [SelectedCount]));
  Writeln('=========================================');
  
  for I := 0 to Packages.Count - 1 do
  begin
    if Packages[I].Selected then
    begin
      Writeln(Format('  [%s] %s (v%s)', [Packages[I].Category, Packages[I].Id, Packages[I].Version]));
    end;
  end;
end;

procedure InstallSelectedPackages(const Packages: TPackageList; const GetItCmd: string);
var
  I: Integer;
  ExitCode: Integer;
  SuccessCount, FailureCount, SelectedCount: Integer;
begin
  SelectedCount := 0;
  SuccessCount := 0;
  FailureCount := 0;
  
  // Count selected packages
  for I := 0 to Packages.Count - 1 do
    if Packages[I].Selected then
      Inc(SelectedCount);
  
  if SelectedCount = 0 then
  begin
    Writeln('No packages selected for installation.');
    Exit;
  end;
  
  Writeln('');
  Writeln(Format('Installing %d selected packages...', [SelectedCount]));
  Writeln('==================================');
  
  var CurrentPackage := 0;
  for I := 0 to Packages.Count - 1 do
  begin
    if Packages[I].Selected then
    begin
      Inc(CurrentPackage);
      Writeln(Format('[%d/%d] Installing: %s', [CurrentPackage, SelectedCount, Packages[I].Id]));
      Writeln(Format('         Category: %s', [Packages[I].Category]));
      
      ExitCode := ExecuteProcessDirect(GetItCmd, Format('-i="%s" -ae -v=minimal', [Packages[I].Id]));
      
      if ExitCode = 0 then
      begin
        Inc(SuccessCount);
        Writeln('         ✓ SUCCESS');
      end
      else
      begin
        Inc(FailureCount);
        Writeln(Format('         ✗ FAILED (Exit Code: %d)', [ExitCode]));
      end;
      
      Sleep(300);
      Writeln('');
    end;
  end;
  
  Writeln('Installation Summary:');
  Writeln('====================');
  Writeln(Format('Total selected: %d', [SelectedCount]));
  Writeln(Format('Successful: %d', [SuccessCount]));
  Writeln(Format('Failed: %d', [FailureCount]));
  
  if SelectedCount > 0 then
  begin
    var SuccessRate := Round((SuccessCount / SelectedCount) * 100);
    Writeln(Format('Success Rate: %d%%', [SuccessRate]));
  end;
end;

procedure ShowHeader;
begin
  Writeln('');
  Writeln('================================================================');
  Writeln('              GetIt Manager v1.0 (Pure Delphi)');
  Writeln('================================================================');
  Writeln('Complete package management solution for RAD Studio');
  Writeln('• Multi-version support');
  Writeln('• Category-based package organization');
  Writeln('• Flexible package selection');
  Writeln('• Bypasses D13 GetItCmd AccessViolation issues');
  Writeln('================================================================');
  Writeln('Copyright (c) 2025 Olaf Monien');
  Writeln('Licensed under the MIT License');
  Writeln('https://github.com/omonien/GetItManager');
  Writeln('================================================================');
  Writeln('');
end;

var
  DelphiVersions: TDelphiVersionList;
  SelectedVersion: Integer;
  CurrentVersion: TDelphiVersion;
  Output: TStringList;
  Packages: TPackageList;
begin
  try
    ShowHeader;
    
    // Detect Delphi versions
    DelphiVersions := DetectDelphiVersions;
    try
      if DelphiVersions.Count = 0 then
      begin
        Writeln('No RAD Studio installations found!');
        Writeln('Please ensure RAD Studio is properly installed.');
        Write('Press Enter to exit...');
        Readln;
        Exit;
      end;
      
      // Select Delphi version
      SelectedVersion := SelectDelphiVersion(DelphiVersions);
      if SelectedVersion < 0 then
      begin
        Writeln('No version selected. Exiting...');
        Exit;
      end;
      
      CurrentVersion := DelphiVersions[SelectedVersion];
      
      Writeln('');
      Writeln(Format('Selected: %s', [CurrentVersion.Name]));
      Writeln(Format('GetItCmd: %s', [CurrentVersion.GetItCmd]));
      Writeln('');
      
      // Query packages using direct console output
      Writeln('Querying GetIt catalog...');
      Writeln('This will display the package list directly from GetIt.');
      Writeln('Due to RAD Studio 13 AccessViolation issues with output redirection,');
      Writeln('we use direct console output for maximum compatibility.');
      Writeln('');
      Writeln('=== GetIt Package Catalog ===');
      
      // Execute GetItCmd and capture console buffer using Windows Console API
      // This approach bypasses AccessViolation issues in RAD Studio 13.0
      Writeln('Executing GetItCmd and capturing console buffer...');
      
      // Use enhanced console buffer method to capture complete GetIt output
      Writeln('Capturing GetIt catalog using enhanced console buffer management...');
      
      try
        Output := CaptureGetItOutputEnhanced(CurrentVersion.GetItCmd, '-l="" -f=all -v=normal');
        
        if Output.Count > 10 then
        begin
          Writeln(Format('Successfully captured %d lines from enhanced console buffer!', [Output.Count]));
          
          Packages := ParsePackages(Output);
          Writeln(Format('Parsed %d packages from GetIt catalog.', [Packages.Count]));
          
          if Packages.Count > 0 then
            begin
              Writeln(Format('Found %d packages in catalog.', [Packages.Count]));
              Writeln('');
              
              // Show packages by category
              ShowPackagesByCategory(Packages);
              
              // Package selection
              SelectPackages(Packages);
              
              // Show selected packages
              ShowSelectedPackages(Packages);
              
              // Confirm installation
              var SelectedCount := 0;
              for var i := 0 to Packages.Count - 1 do
                if Packages[i].Selected then Inc(SelectedCount);
              
              if SelectedCount > 0 then
              begin
                Writeln('');
                Write('Continue with installation? (y/N): ');
                var Choice: string;
                Readln(Choice);
                
                if SameText(Choice, 'y') or SameText(Choice, 'yes') then
                begin
                  InstallSelectedPackages(Packages, CurrentVersion.GetItCmd);
                  
                  Writeln('');
                  Writeln('============================================');
                  Writeln('INSTALLATION COMPLETED!');
                  Writeln('============================================');
                  Writeln('');
                  Writeln('Next steps:');
                  Writeln('  1. RESTART RAD Studio to activate new packages');
                  Writeln('  2. Check Tools > GetIt Package Manager for installed packages');
                  Writeln('  3. For styles: Tools > Options > Application Appearance (VCL)');
                  Writeln('     or Form Designer style selector (FMX)');
                end
                else
                  Writeln('Installation cancelled.');
              end
              else
              begin
                Writeln('No packages selected.');
              end;
              
              Packages.Free;
              Output.Free;
              Exit;
            end
            else
            begin
              Writeln('Console buffer captured but no packages found in parsed output.');
              Writeln('Falling back to manual selection...');
            end;
          end
          else
          begin
            Writeln('Console buffer appears empty or too small. Falling back to manual selection...');
          end;
        
        except
          on E: Exception do
          begin
            Writeln(Format('Failed to capture console output: %s', [E.Message]));
            Writeln('Falling back to manual selection...');
          end;
        end;
      
      
    finally
      DelphiVersions.Free;
    end;
    
  except
    on E: Exception do
    begin
      Writeln(Format('FATAL ERROR: %s', [E.Message]));
    end;
  end;
  
  Writeln('');
  Write('Press Enter to exit...');
  Readln;
end.