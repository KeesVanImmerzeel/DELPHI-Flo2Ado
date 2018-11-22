unit uFlo2Ado;

interface

uses Windows, SysUtils, Classes, Graphics, Forms, Controls, StdCtrls,
  Buttons, ExtCtrls, Dialogs, LargeArrays, AdoSets, OpWString, Mask,
  uTTrishellDataSet, dUtils, uError, System.UITypes;

type
  TOKBottomDlg = class(TForm)
    OKBtn: TButton;
    Bevel1: TBevel;
    Label1: TLabel;
    Label2: TLabel;
    EditFloFileName: TEdit;
    SelectFloFileNameDialog: TOpenDialog;
    SaveAdoFileDialog: TSaveDialog;
    SelectFloFileButton: TButton;
    aRealAdoSet: TRealAdoSet;
    EditSetName: TEdit;
    Label3: TLabel;
    EditOutputSetName: TEdit;
    EditScalingFactor: TMaskEdit;
    Label4: TLabel;
    Label5: TLabel;
    EditDescription: TEdit;
    procedure SelectFloFileButtonClick(Sender: TObject);
    procedure OKBtnClick(Sender: TObject);
    procedure EditOutputSetNameChange(Sender: TObject);
    procedure EditFloFileNameChange(Sender: TObject);
    procedure EditFloFileNameExit(Sender: TObject);
    Function ScalingOk: Boolean;
    Function WriteStartAndNOTEndTimeOfTimeSteps: Boolean;
  private
    { Private declarations }
  public
    { Public declarations }
  end;


var
  OKBottomDlg: TOKBottomDlg;
  ScalingFactor: Double;
  TransientDataSet: TTransientDataSet;
    {CreateFromIniFile( Const IniFileName: String; var lf: TextFile;
      var iError: Integer; AOwner: TComponent ); }

implementation

{$R *.DFM}


Function TOKBottomDlg.WriteStartAndNOTEndTimeOfTimeSteps: Boolean;
begin
  Result := Pos( '<--', EditDescription.Text ) <> 0;
end;

Function TOKBottomDlg.ScalingOk: Boolean;
begin
  Result := False;
  Try
    ScalingFactor := StrToFloat( Trim( EditScalingFactor.Text ) );
    if ScalingFactor = 0 then begin
      ScalingFactor := 1;
      EditScalingFactor.Text := '1';
    end;
  except
    if ( Mode = Interactive ) then
      MessageDlg( 'Invalid Scaling factor: "' + EditScalingFactor.Text + '".',
                mtError, [mbOk], 0)
    else MessageBeep( MB_ICONASTERISK );
    EditScalingFactor.Text := '1';
    exit;
  end;
  Result := True;
end;

procedure TOKBottomDlg.SelectFloFileButtonClick(Sender: TObject);
begin
  if SelectFloFileNameDialog.Execute then begin
    EditFloFileName.Text := SelectFloFileNameDialog.FileName;
    {EditFloFileNameChange(self);}
  end;
end;

procedure TOKBottomDlg.OKBtnClick(Sender: TObject);
var
  f, g: TextFile;
  ISetIdStr, OSetIdStr, IniFileName, AdoTimeStr: String;
  LineNr, NrOfSetsWritten: LongWord;
  Initiated, MoreThanOneAdoSet, ScalingError: Boolean;
  MsgDlgType: TMsgDlgType;
  Save_Cursor:TCursor;
  iError: Integer;
begin

  if ( not FileExists( EditFloFileName.Text ) ) then begin
    if ( Mode = Interactive ) then
      MessageDlg( 'File: "' + ExpandFileName( EditFloFileName.Text ) + '" does not exist.',
                  mtError, [mbOk], 0)
    else MessageBeep( MB_ICONASTERISK );
    exit;
  end;

  if not ScalingOk then exit;

  With SaveAdoFileDialog do begin
    if ( Mode = Batch ) or ( ( Mode = Interactive ) and Execute ) then begin
      Try

        WriteToLogFile(  'Opening file: "' + EditFloFileName.Text + '"' );
        AssignFile( f, EditFloFileName.Text ); Reset( f );
      except
        Try CloseFile( f ); except end;
        if ( Mode = Interactive ) then
          MessageDlg( 'Error opening file "' + EditFloFileName.Text + '"' + #13 +
                      'Check "Flo2Ado.log"', mtError, [mbOk], 0)
        else MessageBeep( MB_ICONASTERISK );
        Exit;
      end;

      if WriteStartAndNOTEndTimeOfTimeSteps then begin
        WriteToLogFile(  'WriteStartAndNOTEndTimeOfTimeSteps' );
        IniFileName := ExtractFileDir( EditFloFileName.Text ) + '\' + 'model.ini';
        TransientDataSet := TTransientDataSet.CreateFromIniFile( IniFileName, iError, self );
        if ( IError <> 0 ) then begin
          MessageDlg ( 'Cannot initialise TransientDataSet.' + #13 +
                      'Check "Flo2Ado.log"', mtError, [mbOk], 0);
          exit;
        end;
      end;

      Try
        AssignFile( g, FileName ); Rewrite( g );
        WriteToLogFile(  'Creating file: "' + FileName + '"' );
      except
        if ( Mode = Interactive ) then
          MessageDlg( 'Error creating file "' + FileName + '"' + #13 +
                      'Check "Flo2Ado.log"', mtError, [mbOk], 0)
        else MessageBeep( MB_ICONASTERISK );
        Exit;
      end;
      NrOfSetsWritten   := 0;
      LineNr            := 1;
      ISetIdStr         := UpperCase( Trim( EditSetName.Text ) ) + '$';
      MoreThanOneAdoSet := MoreThanOneSetsLike_SetIdStr( f, ISetIdStr );
      ScalingError      := False;
      Save_Cursor       := Screen.Cursor;
      Screen.Cursor     := crHourglass;    { Show hourglass cursor }
      Try
        Repeat
          Try
            aRealAdoSet := TRealAdoSet.InitFromOpenedTextFile( f, ISetIdStr,
                           self, LineNr, Initiated );
          except
            Initiated := False;
          end;
          if Initiated then begin

            Inc( NrOfSetsWritten );

            OSetIdStr := UpperCase( Trim( EditOutputSetName.text ) );

            if WriteStartAndNOTEndTimeOfTimeSteps then begin
              with TransientDataSet do begin
                AdoTimeStr := GetAdoTimeStr( GetPreviousOutputTime( GetStartTime + aRealAdoSet.AdoTime ) - GetStartTime );
                OSetIdStr := OSetIdStr + AdoTimeStr;
              end;
            end else begin
              if MoreThanOneAdoSet then begin
                AdoTimeStr := GetAdoTimeStr( aRealAdoSet.AdoTime );
                OSetIdStr := OSetIdStr + AdoTimeStr;
              end;
            end;

            aRealAdoSet.SetIdStr := OSetIdStr;

            ScalingError := ( not aRealAdoSet.Process( Multiply, ScalingFactor ) );
            if ScalingError then begin
              if ( Mode = Interactive ) then
                MessageDlg( 'Error scaling set: "' + OSetIdStr + '".',
                            mtError, [mbOk], 0)
              else MessageBeep( MB_ICONASTERISK );
            end else begin
              aRealAdoSet.ExportToOpenedTextFile( g );
            end;

            try aRealAdoSet.free; except; end;
          end;
        until ( ( EOF( f ) ) or ( not Initiated ) or ScalingError );
      finally
        Screen.Cursor := Save_Cursor;
      end;
      WriteToLogFileFmt(  'NrOfSetsWritten: %s.', [IntToStr( NrOfSetsWritten )] );
      if WriteStartAndNOTEndTimeOfTimeSteps then begin
        Try
          TransientDataSet.Free;
        except
        end;
      end;
      CloseFile( f );
      CloseFile( g );

      if ( NrOfSetsWritten > 0 ) then
        MsgDlgType := mtInformation
      else begin
        MsgDlgType := mtWarning;
        if ( Mode = Batch ) then MessageBeep( MB_ICONASTERISK );
      end;

      if ( Mode = Interactive ) then
        MessageDlg( 'NrOfSetsWritten: ' + IntToStr( NrOfSetsWritten ),
                   MsgDlgType, [mbOk], 0);
    end; {-if Execute}
  end; {-With SaveDialog }
end;

procedure TOKBottomDlg.EditOutputSetNameChange(Sender: TObject);
begin
  if EditOutputSetName.Modified then
    SaveAdoFileDialog.FileName := Trim( EditOutputSetName.Text ) + '.ado';
end;

procedure TOKBottomDlg.EditFloFileNameChange(Sender: TObject);
var
  lf, f: TextFile;
  ResultSetIDStr: String;
  var LineNr: LongWord;
begin
  if FileExists( EditFloFileName.Text ) then begin
    Try
      AssignFile( lf, 'Flo2Ado.log' ); Rewrite( lf );
      WriteToLogFile(  'Opening file: "' + EditFloFileName.Text + '"' );
      AssignFile( f, EditFloFileName.Text ); Reset( f );
    except
      Try
        CloseFile( f ); Exit;
      except end;
    end;
    LineNr   := 0;
    if FindSet( f, '*', ResultSetIDStr, LineNr ) then
      EditSetName.Text := MainPartOf_SetIdStr( ResultSetIDStr );
    CloseFile( f );
  end;
end;

procedure TOKBottomDlg.EditFloFileNameExit(Sender: TObject);
begin
  EditFloFileNameChange(self);
end;

initialization
finalization
end.
