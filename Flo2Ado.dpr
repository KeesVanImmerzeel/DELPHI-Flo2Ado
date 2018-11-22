program Flo2Ado;

uses
  Forms,
  uFlo2Ado in 'uFlo2Ado.pas',
  IniFiles,
  OpWString,
  Dutils,
  SysUtils,
  Dialogs,
  uError,
  windows;

var
  f_ini: TiniFile;
  RunDirStr, cfgFileStr, MapFileStr, ExpressionStr, DefaultStr, DescriptionStr,
  ResultFileStr, ResultSetStr, CurrDirBuf: String;

{$R *.RES}

begin
  Application.Initialize;
  Application.CreateForm(TOKBottomDlg, OKBottomDlg);
  InitialiseLogFile;

  if ( ParamCount >= 3 ) then begin
    Mode := Batch;
    RunDirStr   := ParamStr( 1 );
    cfgFileStr  := RunDirStr + '\' + ParamStr( 3 );
    f_ini := TiniFile.Create( cfgFileStr );
    MapFileStr     := f_ini.ReadString( 'Allocator', 'datasource', 'Error' ); {-Triwaco 4}
    if ( MapFileStr = 'Error' ) then begin
      MapFileStr     := f_ini.ReadString( 'Allocator', 'mapfile', 'Error' ); {-Triwaco 3}
      ExpressionStr  := f_ini.ReadString( 'Allocator', 'expression', 'Error' );
      {MessageDlg( 'triwaco 3', mtInformation, [mbOk], 0);}
    end else begin
      ExpressionStr  := f_ini.ReadString( 'Allocator', 'layer', 'Error' );  {-Triwaco 4}
      {MessageDlg( 'triwaco 4', mtInformation, [mbOk], 0);} 
    end;
    DefaultStr     := f_ini.ReadString( 'Allocator', 'default', 'Error' );
    ResultFileStr  := f_ini.ReadString( 'Allocator', 'resultfile', 'Error' );
    ResultSetStr   := f_ini.ReadString( 'Allocator', 'setname', 'Error' );
    DescriptionStr := f_ini.ReadString( 'Allocator', 'description', 'Error' );
    f_ini.Free;
    if pos( 'DEBUG', Uppercase( DescriptionStr ) ) <> 0 then
      Mode := Interactive;
    with OKBottomDlg do begin
      EditFloFileName.Text       := MapFileStr;
      EditSetName.Text           := ExpressionStr;
      EditScalingFactor.Text     := DefaultStr;
      EditOutputSetName.text     := ResultSetStr;
      SaveAdoFileDialog.FileName := ResultFileStr;
      EditDescription.Text := DescriptionStr;
      CurrDirBuf := GetCurrentDir;
      SetCurrentDir( ExtractFileDir( ResultFileStr ) );
      if not ScalingOk and ( Mode = Batch ) then begin
        MessageBeep( MB_ICONASTERISK ); SetCurrentDir( CurrDirBuf ); Exit;
      end;
    end;
  end;

   {Application.Run;}
  if ( Mode = Interactive ) then begin
    {MessageDlg( 'Interactive', mtInformation, [mbOk], 0); }
    Application.Run;
  end else begin
    {MessageDlg( 'Batch', mtInformation, [mbOk], 0); }
    OKBottomDlg.OKBtn.Click;
  end;
  SetCurrentDir( CurrDirBuf );

  FinaliseLogFile;
end.
