unit uMain;

interface

procedure Main();
implementation

uses uMPparser,SysUtils,zADODB, ComObj, ADOInt,Variants,Classes,uVB6runtime,uRoutingTest ;



procedure AddCity(name:string; latlon:TLatLon;Population:Integer);
begin
  //Writeln(name,' ',Population, ' (', FormatFloat('#,00.000',lat),',',FormatFloat('#,00.000',lon),')');
 // Writeln(name,' ',Population, ' (', latlon,')');

  rsCities.AddNew(EmptyParam,EmptyParam);
  rsCities.Fields[RS_CITY_NAME].value:=name;
  rsCities.Fields[RS_CITY_POPULATION].value:=Population;
  rsCities.Fields[RS_CITY_COORDS].value:=latlon;
  rsCities.Update(EmptyParam,EmptyParam);
end;

procedure ParseLatLon(var lat,lon:real;latLon:string);
var j:integer;
begin
    j:=Pos(',',latlon);

    lat := StrToFloat(Copy(latlon,1,j-1));
    lon:= StrToFloat(Copy(latlon,j+1,length(latlon)-j));
end;

procedure AddRoad(MpSection:TMpSection);
var
  strDir,strData0:string;
  lstNodes:TStringList;
  intRoadID:integer;
  i,j:integer;
  latlon:string;
  RoutingNodes:array[0..999,1..2] of integer;
  strNodeAttr:string;
  NN:integer;
  lstRNode:TStringList;
begin
//  writeln(MpSection.GetAttributeValue('Label'));

  intRoadID:=StrToInt(MpSection.GetAttributeValue('RoadID'));//rsRoads.RecordCount+1;
  rsRoads.AddNew(EmptyParam,EmptyParam);

  //�����, ������ �� �������
  rsRoads.Fields[RS_ROAD_ID].value:= intRoadID;
  rsRoads.Fields[RS_ROAD_STATUS].value:=OSMLevelByTag(MpSection.GetOsmHighway);

  //����������� ����������� ��������
  strDir:=MpSection.GetAttributeValue('DirIndicator');
  if strDir='' then
    rsRoads.Fields[RS_ROAD_ONEWAY].value:=0
  else
    rsRoads.Fields[RS_ROAD_ONEWAY].value:=strToInt(strDir);

  rsRoads.Update(EmptyParam,EmptyParam);

  //���������� ����
   NN:=0;
   repeat
     strNodeAttr := MpSection.GetAttributeValue('Nod' + intToStr(NN));
     If strNodeAttr <> '' Then
       begin
          lstRNode := Split(strNodeAttr, ',');
          RoutingNodes[NN,  1] := strToInt(lstRNode[0]);
          RoutingNodes[NN , 2] := strToInt(lstRNode[1]);
          lstRNode.Free;
          NN:= NN + 1
        End;

   Until strNodeAttr = '';


  //������� ������ ������ (����������).
  //�� ����� ������� �� ������.
  strData0:=MpSection.GetAttributeValue('Data0');

  //(x1,y1),(x2,y2),(x3,y3), ...,(xN,yN)
  lstNodes := Split(strData0, '),');

  For i:= 0 To lstNodes.Count-1 do
  begin

    rsNodes.AddNew(EmptyParam,EmptyParam);

    rsNodes.Fields[RS_NODE_ROADID].Value := intRoadID;
    rsNodes.Fields[RS_NODE_ORDERNO].Value := i;

    latlon:=lstNodes[i];
    if vb6_Left(latlon,1)='('  then
      latlon:=copy(latlon,2,length(latlon)-1);

    if vb6_Right(latlon,1)=')'  then
      latlon:=copy(latlon,1,length(latlon)-1);

 //   writeln(latlon);
    j:=Pos(',',latlon);

    rsNodes.Fields[RS_NODE_LAT].Value := StrToFloat(Copy(latlon,1,j-1));
    rsNodes.Fields[RS_NODE_LON].Value := StrToFloat(Copy(latlon,j+1,length(latlon)-j));
        rsNodes.Fields[RS_NODE_ROUTINGNODE].value:= trim('');

    for j := 0 to NN-1 do
      begin
        if RoutingNodes[j,1]=i then
        begin
          rsNodes.Fields[RS_NODE_ROUTINGNODE].value:= trim(IntToStr(RoutingNodes[j,2]));
          break;
        end;
      end;



      //strX := Trim(Split(tmp(i), ",")(0)) //������
      //strY := Trim(Split(tmp(i), ",")(1)) //������
      //'������

      //coords(i, 0) = Right(strX, Len(strX) - 1)
  end;

  lstNodes.Free;
end;



Procedure Main();
const strFileName='d:\OSM\_osm2dcm\RoutingTest\RU-KGD.mp';

var MpParser:TMpParser;
    MpSection:TMpSection;
    T0,T1:TDateTime;
    lat1,lon1,lat2,lon2:real;
    rsRoute:zADODB.Recordset;
begin
  Writeln('RoutingTest, (c) Zkir 2012, CC-BY-SA 2.0 ');

  Writeln('Loading map: ',strFileName);
  T0:=Now;

{ 1. �������� �������� ����.
     * ���������� ������ ������� ��� ���������� ���������
     * ��������� ����� ������������� ��������� ����� }
  MpParser:=TMpParser.Create(strFileName);

  //�������� ������ �������
  rsCities:= CoRecordset.Create;
  rsCities.Fields.Append( RS_CITY_NAME, adWChar, 255,0,EmptyParam);
  rsCities.Fields.Append( RS_CITY_POPULATION, adInteger,0,0,EmptyParam);
  rsCities.Fields.Append( RS_CITY_COORDS, adWChar, 255,0,EmptyParam);
  //rsCities.Fields.Append( RS_CITY_VALID, adInteger);
  //rsCities.Fields.Append( RS_CITY_ORIGTYPE, adWChar, 255);
  rsCities.Open (EmptyParam,EmptyParam,adOpenStatic, adLockBatchOptimistic,  adCmdText);

  //�������� ������ �����
    //� ��������, ����� ������ ����� � ������� ���������������.
  rsRoads:= CoRecordset.Create;
  rsRoads.Fields.Append( RS_ROAD_ID, adInteger, 0,0,EmptyParam);
  rsRoads.Fields.Append( RS_ROAD_ONEWAY, adInteger,0,0,EmptyParam);
  rsRoads.Fields.Append( RS_ROAD_STATUS, adInteger,0,0,EmptyParam);
  rsRoads.Open (EmptyParam,EmptyParam,adOpenStatic, adLockBatchOptimistic,  adCmdText);

  //�������� ������ ������.
    //� ����� ������ ������, ����� �� ������� � ������ ������, ����������,
    //� ����� �� ������� � ������ �������.
   //�������

  rsNodes:= CoRecordset.Create;
  rsNodes.Fields.Append( RS_NODE_ROADID, adInteger, 0,0,EmptyParam);
  rsNodes.Fields.Append( RS_NODE_ORDERNO, adInteger, 0,0,EmptyParam);

  rsNodes.Fields.Append( RS_NODE_LAT, adDouble, 0,0,EmptyParam);
  rsNodes.Fields.Append( RS_NODE_LON, adDouble, 0,0,EmptyParam);

  rsNodes.Fields.Append( RS_NODE_ROUTINGNODE, adWChar, 4,0,EmptyParam);

  rsNodes.Open (EmptyParam,EmptyParam,adOpenStatic, adLockBatchOptimistic,  adCmdText);

  //������ �������� ����.
   while not MpParser.EOF do
   begin
     MpSection:=MpParser.ReadNextSection;

     //������� ����� � ������ �������
     If MpSection.SectionType = '[POI]' Then
       If MpSection.GetAttributeValue('City') = 'Y' Then
         if MpSection.GetAttributeValue('Population')<>'' then
           AddCity(MpSection.GetAttributeValue('Label'),
                   MpSection.GetCoords,
                   StrToInt(MpSection.GetAttributeValue('Population')) );

     //������� ������ � ���� �������
     If (MpSection.SectionType = '[POLYLINE]') Then
       If (MpSection.mpRouteParam <> '') Then
       If OSMLevelByTag(MpSection.GetOsmHighway) <= 2 Then
       begin
           AddRoad(MpSection);

       end;


     MpSection.Free;
   end;



  T1:=now;
  Writeln('Map loaded, in ',FormatFloat('#0.00', (T1-T0)*24*60*60),'  second(s)');

  Writeln('Cities :',rsCities.RecordCount);
  Writeln('Roads :',rsRoads.RecordCount);
  Writeln('Nodes :',rsNodes.RecordCount);

  MpParser.Free;

{ 2. ����� �������� ������� ���������� ��������}
  rsCities.sort:=RS_CITY_POPULATION +' desc';
  rsCities.MoveFirst;
  writeln(rsCities.Fields[RS_CITY_NAME].Value, ' ',rsCities.Fields[RS_CITY_COORDS].Value );

  ParseLatLon(lat1,lon1,rsCities.Fields[RS_CITY_COORDS].Value);

  rsCities.MoveNext;

  writeln(rsCities.Fields[RS_CITY_NAME].Value, ' ',rsCities.Fields[RS_CITY_COORDS].Value  );
  ParseLatLon(lat2,lon2,rsCities.Fields[RS_CITY_COORDS].Value);

  rsRoute:=FindRoute(lat1,lon1,lat2,lon2);
  //rsRoute:=FindRoute(lat2,lon2,lat1,lon1);
  writeln('Route ',rsRoute.RecordCount,' node(s)');


 {
  //��� ������ ����.
  rsNodes.Filter:=RS_NODE_ROADID+'=1';
  repeat
    writeln(rsNodes.Fields[RS_NODE_LAT].Value, ' ',rsNodes.Fields[RS_NODE_LON].Value,' ',rsNodes.Fields[RS_NODE_ROUTINGNODE].Value  );
    rsNodes.MoveNext;
  until rsNodes.EOF;}

{ 4. ����������� �������� ��������� � XML (������� ������� ����� ������). }
//� gpx)
end;


end.
