unit uRoutingTest;
(*���� �������
 ��� �� ���������� �������:

 1. �������� �������� ����.
 2. ���������� ������ �������
 3. ����� �������� ������� ���������� ��������
 4. ����������� �������� ��������� � XML (������� ������� ����� ������).
  �������� ����� ����� ����� ����������, � ������, ��� ���� ������� ���������� ��
  ���� ��� ���� ������, ������ ���� �����������.
  ���� ���-�� � ��� ������ ����� ����������� ������, �������� ������ ����������.
*)

interface
uses zADODB,ComObj, ADOInt,Variants, SysUtils,Classes,Contnrs;


Const


{//������
 RS_ROAD_ID  = 'RoadID';
 RS_ROAD_ONEWAY  = 'Oneway';
 RS_ROAD_STATUS  = 'Status';}

//�������
 RS_NODE_ROADID = 'RoadID';
 RS_NODE_ORDERNO = 'OrderNo';
 //RS_NODE_LAT = 'Lat';
 //RS_NODE_LON = 'Lon';
 RS_NODE_ROUTINGNODE = 'RoutingNode';

 type TVertex=record
   Lat:double;
   Lon:double;
   RoutingNodeID:integer;
 end;


 type TRoad=record
   OneWay:integer;
   Status:integer;
   Vertex:array of TVertex;
 end;

var
  arRoads:array [0..10000] of TRoad;

{  rsRoads: zADODB.Recordset;}
  rsNodes: zADODB.Recordset;

Const GREEDY_LEVEL=1.1;


type

  // ������� ��������.
  // ��� ������� � ��������� �������� � ������ � ��(?)
  TRouteElement = class
      RoadId:integer;
      RoadDir:integer;
      RoadStatus:integer;
      NodeNumber:integer;
      lat:real;
      lon:real;
      intRoutingNodeNo:integer;
      constructor Create(aRoadId:integer; aNodeNumber:integer);Overload;
      //constructor Create(aRoadId:integer; aNodeNumber:integer;aLat,aLon:Real;aRoutingNodeNo:integer);Overload;
      constructor CreateCopy(Source:TRouteElement);
      //destructor Destroy; Override;
  end;


  // ������� - ������ ������, �������� � ����
  TRoute=class
    private
      FRouteElements:TObjectList;
      Length:real;//������ ���������� �����
      RemainingLength:real;//������ ������ ���������� �����

      //������� �������� ����� ��������
      FinishLat:real;
      FinishLon:real;
      StatusExtremumCount:integer;
      PrevStatus:integer;
      CurrentStatusDir:integer;
      PrevStatusDir:integer;

      function GetElementCount:integer;
      function GetElement(Index : Integer):TRouteElement;
    public

      property ElementCount:integer read GetElementCount;
      property Elements[Index : Integer]:TRouteElement  read GetElement;  default;

      constructor CreateInitialRoute(aStartRoadID,aStartNodeID,aFinishRoadID,aFinishNodeID:integer);
      constructor ContinueRoute(aRoute:TRoute; Continuation:TRouteElement);
      function TestLoops:boolean;
      function TestClassVariance:boolean;

      function TestFinish:boolean;
      function TestDuplicate(aRoute:TRoute):boolean;
      //constructor CreateCopy(Source:TSyntaxPattern);

      destructor Destroy; override;
      function FullLength:real;
      Function GetLengthKm:real;
      Procedure SaveToGpx(strFileName,strComment:string);
      //function AsString():String;
  end;

Function FindRoute(lat1,lon1,lat2,lon2:real):TRoute;

implementation



constructor TRouteElement.Create(aRoadId:integer; aNodeNumber:integer);
begin

  RoadId:=aRoadId;
  NodeNumber:=aNodeNumber;

  lat:=arRoads[RoadId].Vertex[aNodeNumber].lat; //rsNodes.Fields[RS_NODE_LAT].Value;
  lon:=arRoads[RoadId].Vertex[aNodeNumber].lon;//rsNodes.Fields[RS_NODE_LON].Value;
  intRoutingNodeNo:=arRoads[RoadId].Vertex[aNodeNumber].RoutingNodeID ;//rsNodes.Fields[RS_NODE_ROUTINGNODE].Value;


  //rsRoads.Filter:=RS_ROAD_ID+'='+IntToStr(RoadId);
  RoadDir:=arRoads[RoadId].OneWay;  //rsRoads.Fields[RS_ROAD_ONEWAY].Value ;
  RoadStatus:=arRoads[RoadId].Status;//rsRoads.Fields[RS_ROAD_STATUS].Value;
  //rsRoads.Filter:=adFilterNone;
end;

(*
constructor TRouteElement.Create(aRoadId:integer; aNodeNumber:integer;aLat,aLon:Real;aRoutingNodeNo:integer);

begin
  RoadId:=aRoadId;
  NodeNumber:=aNodeNumber;
  lat:=aLat;
  lon:=aLon;
  intRoutingNodeNo:=aRoutingNodeNo;

  //rsRoads.Filter:=RS_ROAD_ID+'='+IntToStr(RoadId);
  RoadDir:=arRoads[RoadId].OneWay;  //rsRoads.Fields[RS_ROAD_ONEWAY].Value ;
  RoadStatus:=arRoads[RoadId].Status;//rsRoads.Fields[RS_ROAD_STATUS].Value;
  //rsRoads.Filter:=adFilterNone;
end;
*)

constructor  TRouteElement.CreateCopy(Source:TRouteElement) ;
begin
  RoadId:=Source.RoadId;
  NodeNumber:=Source.NodeNumber ;
  lat:=Source.lat;
  lon:=Source.lon;
  intRoutingNodeNo:=Source.intRoutingNodeNo;

  RoadDir:=Source.RoadDir;
  RoadStatus:=Source.RoadStatus;
end;


//���������� ����� ����� �������
Function Distance(const lat1,lon1,lat2,lon2:double):double;
begin
  //��� �������� ��������� ����� � ��������.
  result:=sqrt(sqr(lat2-lat1)+sqr(lon2-lon1));
end;

Function DistanceKm(const lat1,lon1,lat2,lon2:double):double;
Const DEG_LEN=111.2;
begin
  //��� �������� ��������� ����� � ��������.
  result:=sqrt(sqr(DEG_LEN*(lat2-lat1))+sqr(DEG_LEN*cos((lat1+lat2)/2/180*Pi)*(lon2-lon1)));
end;

constructor TRoute.CreateInitialRoute(aStartRoadID,aStartNodeID,aFinishRoadID,aFinishNodeID:integer);
var aNode:TRouteElement;
begin
  FRouteElements:=TObjectList.Create;
  aNode:=TRouteElement.Create(aStartRoadID,aStartNodeID);
  FRouteElements.Add(aNode);
  Length:=0;

  //rsNodes.Filter:= RS_NODE_ROADID+'='+IntToStr(aFinishRoadID)+' and '+
  //                 RS_NODE_ORDERNO+'='+IntTostr(aFinishNodeID);


  FinishLat:=arRoads[aFinishRoadID].Vertex[aFinishNodeID].lat;//  rsNodes.Fields[RS_NODE_LAT].Value;
  FinishLon:=arRoads[aFinishRoadID].Vertex[aFinishNodeID].lon;//rsNodes.Fields[RS_NODE_LON].Value;
  //rsNodes.Filter:=adFilterNone;

  RemainingLength:=Distance(Elements[0].Lat,
                            Elements[0].Lon,
                            FinishLat,FinishLon);
  StatusExtremumCount:=0;
  PrevStatus:=5;
  CurrentStatusDir:=0;
  PrevStatusDir:=0;
end;

constructor TRoute.ContinueRoute(aRoute:TRoute; Continuation:TRouteElement);
var
  i:integer;
begin
  FRouteElements:=TObjectList.Create;
  //C���������� ������� ��������� ��������
  Length:=aRoute.Length;
  RemainingLength:=aRoute.RemainingLength;
  FinishLat:=aRoute.FinishLat;
  FinishLon:=aRoute.FinishLon;

  PrevStatus:=aRoute.PrevStatus;
  CurrentStatusDir:=aRoute.CurrentStatusDir;
  PrevStatusDir:=aRoute.PrevStatusDir;

  StatusExtremumCount:=aRoute.StatusExtremumCount;

  for i := 0 to aRoute.ElementCount-1 do
    FRouteElements.Add(TRouteElement.CreateCopy(aRoute[i]));
  //������� ����� �������
  FRouteElements.Add(TRouteElement.CreateCopy(Continuation));

  //����������� �����
  Length:=Length+Distance(Elements[ElementCount-2].Lat,
                          Elements[ElementCount-2].Lon,
                          Elements[ElementCount-1].Lat,
                          Elements[ElementCount-1].Lon);

  RemainingLength:=Distance(Elements[ElementCount-1].Lat,
                            Elements[ElementCount-1].Lon,
                            FinishLat,FinishLon);

  //�������� ������������� ������� �����. �������� ������������ ������� �������

   //4 3 2 1 1 1 1 2 3 4 4 3 3 4
   if Continuation.RoadStatus< PrevStatus then
     begin //�� �� ���������� �����

       PrevStatus:= Continuation.RoadStatus;
       PrevStatusDir:=CurrentStatusDir;
       CurrentStatusDir:=-1;
     end;

   if Continuation.RoadStatus> PrevStatus then
     begin //�� �� ���������� �����

       PrevStatus:= Continuation.RoadStatus;
       PrevStatusDir:=CurrentStatusDir;
       CurrentStatusDir:=1;
     end;

   //��������� ����������� �����, ����� ������ ��������� �������
   if CurrentStatusDir*PrevStatusDir<0 then
     StatusExtremumCount:=StatusExtremumCount+1;


end;

destructor TRoute.Destroy;
begin
  FRouteElements.Free;
end;

function TRoute.GetElement(Index : Integer):TRouteElement;
begin
  Result:=TRouteElement(FRouteElements[Index]);
end;

function TRoute.GetElementCount:integer;
begin
  Result:=FRouteElements.Count;
end;

function TRoute.TestFinish():boolean;
begin
  Result:=not (RemainingLength>0);
end;

function TRoute.FullLength:real;
begin
  Result:=Length/GREEDY_LEVEL+RemainingLength;
end;

function TRoute.TestLoops:boolean;
var i:integer;
begin
  Result:=False;
  for i :=ElementCount-2  downto 0  do
   if (Elements[i].lat=Elements[ElementCount-1].lat) and(Elements[i].lon=Elements[ElementCount-1].lon)     then
   begin
     Result:=true;
     break;
   end;

end;

function TRoute.TestClassVariance:boolean;
begin
   Result:=(StatusExtremumCount>0);
end;

//���������, ��� ��� �������� ����� � ���� � �� �� �����.
function TRoute.TestDuplicate(aRoute:TRoute):boolean;
begin
  Result:=False;
  if (Elements[ElementCount-1].lat=aRoute.Elements[aRoute.ElementCount-1].lat ) and
     (Elements[ElementCount-1].lon=aRoute.Elements[aRoute.ElementCount-1].lon ) then
    Result:=True;

end;

//������ � ����������, ��� ��� ��� ���������� � ��������.
Function TRoute.GetLengthKm:real;
var i:integer;
begin
 Result:=0;
 for i := 0 to ElementCount-2  do
   Result:=Result+ DistanceKM(Elements[i].lat,Elements[i].lon, Elements[i+1].lat,Elements[i+1].lon);
end;

Procedure TRoute.SaveToGpx(strFileName,strComment:string);
var
  xml:TStringList;
  i:integer;
begin
  xml:=TStringList.Create;
  xml.Add('<?xml version="1.0" encoding="WINDOWS-1251"?>');
  xml.Add('<gpx xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" version="1.0" xmlns="http://www.topografix.com/GPX/1/0" creator="Polar WebSync 2.3 - www.polar.fi" xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">');
  xml.Add('<time>2011-09-22T18:56:51Z</time>');
  xml.Add('<trk>');
  xml.Add('  <name>'+strComment+ '</name>');
  xml.Add('  <trkseg>');
  for i := 0  to self.ElementCount-1 do
  begin
    xml.Add('    <trkpt lat="'+FormatFloat('#0.0000000000',self[i].lat) +'" lon="'+FormatFloat('#0.0000000000',self[i].lon)+'"/>');
    //xml.Add('    </trkpt>');
  end;
  xml.Add('  </trkseg>');
  xml.Add('</trk>');
  xml.Add('</gpx>');
  xml.SaveToFile(strFileName);
  xml.Free;

end;


//����� ������� �������. ������ ������, �������� ����� ���������� ������ �������.
function GetContinuationsList(aRoute:TRoute):TObjectList;
var CurrentNode,NewNode:TRouteElement;
  StartRoadID,StartNodeID:integer;
  intRoutingNodeNo:integer;

  NewRoadId,NewNodeNumber:integer;
  rsLinkedNodes:Recordset;

  dir:integer;

begin
  Result:=TObjectList.Create;
  CurrentNode:=aRoute.Elements[aRoute.ElementCount-1];
  intRoutingNodeNo:=CurrentNode.intRoutingNodeNo;


  //�� ������� ������ ����� �/��� ����.
  dir:=0;
  if aRoute.ElementCount>=2  then
    if aRoute[aRoute.ElementCount-1].RoadId = aRoute[aRoute.ElementCount-2].RoadId  then
    begin
      if (aRoute[aRoute.ElementCount-1].NodeNumber - aRoute[aRoute.ElementCount-2].NodeNumber)>0   then
        dir:=1
       else
        dir:=-1;
    end;

  if CurrentNode.RoadDir<>0 then
    dir:=CurrentNode.RoadDir;


if (dir=0) or  (dir=1) then
begin

  if (CurrentNode.NodeNumber+1)<=High(arRoads[CurrentNode.RoadID].Vertex)   then
  begin
    NewNode:=TRouteElement.Create(CurrentNode.RoadID, CurrentNode.NodeNumber+1 );
    Result.Add(NewNode);
  end;
end;
if (dir=0) or  (dir=-1) then
begin

  if (CurrentNode.NodeNumber-1)>=Low(arRoads[CurrentNode.RoadID].Vertex)  then
  begin
    NewNode:=TRouteElement.Create(CurrentNode.RoadID,CurrentNode.NodeNumber-1  );
    Result.Add(NewNode);
  end;
end;

  //�� ������� ������� ����� � ����.

  if intRoutingNodeNo<>-1 then
  begin
     rsLinkedNodes:=rsNodes.Clone( adLockBatchOptimistic ) ;
     rsLinkedNodes.Filter:= RS_NODE_ROUTINGNODE+'='+IntToStr(intRoutingNodeNo);
    //��� �� ����� �������, ������� � ������.
     while not rsLinkedNodes.EOF do
     begin
       NewRoadId:= rsLinkedNodes.Fields[RS_NODE_ROADID].Value;
       NewNodeNumber := rsLinkedNodes.Fields[RS_NODE_ORDERNO].Value;
       if (NewRoadId<>CurrentNode.RoadID) then
       begin

         if NewNodeNumber+1<=High(arRoads[NewRoadID].Vertex)   {rsNodes.RecordCount<>0}  then
         begin
            NewNode:=TRouteElement.Create(NewRoadID,NewNodeNumber+1 );
            Result.Add(NewNode);
         end;

         if NewNodeNumber-1>=Low(arRoads[NewRoadID].Vertex)  then
         begin
           NewNode:=TRouteElement.Create(NewRoadID,NewNodeNumber-1);
           Result.Add(NewNode);
         end;

       end;
       rsLinkedNodes.Movenext;
     end;

  end;

  rsNodes.Filter:=adFilterNone;

end;

{ ������ ����� ���������� :)
    �������� � ���������� ���������.
    �� ������ ���� � ������� ��������� ��������� �����.

    �� ������ ���� ��������� - ������� �������� ��������������� �������.
    ��� ���� ������� ����� ���� �������� �����������, �� ��������� � ���������, � ��� ������� ���������.
    ���������� �� ��� ���, ���� �������� ����� �� ����� ����������
 }
Function CreateRoute(StartRoadID,StartNodeID:integer;
                     FinishRoadID,FinishNodeID:integer):TRoute;
var
  FWorkingSet,Continuations:TObjectList;
  aRoute:TRoute;
  i:integer;
  K:integer;
  l:real;
begin
  FWorkingSet:= TObjectList.Create;

  aRoute:=TRoute.CreateInitialRoute(StartRoadID,StartNodeID,FinishRoadID,FinishNodeID);
  FWorkingSet.Add(aRoute);
  repeat
    //������ �������� ��������������� ������� ��� �����������

    K:=FWorkingSet.Count-1; //���� �������� ���������������
                     //�������� ��� �����������, ������� � ����� �������.

    l:=TRoute(FWorkingSet[K]).FullLength;
    for i := FWorkingSet.Count-1 downto 0  do
      if TRoute(FWorkingSet[i]).FullLength<l then
      begin
        l:=TRoute(FWorkingSet[i]).FullLength;
        K:=i;
      end;

    //�������� ���������.
    for i := FWorkingSet.Count-1 downto 0 do
      if i<>K then
        if TRoute(FWorkingSet[i]).TestDuplicate(TRoute(FWorkingSet[K])) then
        begin
          FWorkingSet.Delete(i);
          if K>i then K:=K-1;
          writeln('Duplicate deleted');

        end;

  //  writeln('*', FWorkingSet.Count,' ',TRoute(FWorkingSet[K]).FullLength,' ',
  //          TRoute(FWorkingSet[K]).RemainingLength,' ', TRoute(FWorkingSet[K]).ElementCount  );

    if (TRoute(FWorkingSet[K]).TestFinish()) or
        (TRoute(FWorkingSet[K]).ElementCount>1000 )  then  break;

    //���� ��������  ������ ������, �������� ����� ��������� ������ �������
    Continuations:=GetContinuationsList(TRoute(FWorkingSet[K]));
    for i := 0 to Continuations.Count-1  do
    begin
      aRoute:=TRoute.ContinueRoute(TRoute(FWorkingSet[K]),
                                   TRouteElement(Continuations[i]));
      if (not aRoute.TestLoops) {and (not aRoute.TestClassVariance)} then
        FWorkingSet.Add(aRoute)
      else
       aRoute.Free;
    end;
    //����� ���� ��� ��� ��������� ����������� ����������, ������� ���������.
    FWorkingSet.Delete(K);
    Continuations.Free;



  until (FWorkingSet.Count=0);

  Result:= TRoute(FWorkingSet[K]);
  //��������� ������� ��������� �� ������
  FWorkingSet.Extract(Result);

  FWorkingSet.Free;
end;


//�������, ������� �� �������� ��������� � �������� ����� ��������� �������.
Function FindRoute(lat1,lon1,lat2,lon2:real):TRoute;
var
  StartRoadID,StartNodeID:integer;
  FinishRoadID,FinishNodeID:integer;
  CurrentRoadID,CurrentNodeID:integer;
  DStart,DFinish:real;
  DStartMin,DFinishMin:real;
  aRoute:TRoute;
  i:integer;
Begin

  //����� ����� ��������� � �������� �����, ������������� �����, ��������� � ��������

  //����� ������ �������
  rsNodes.MoveFirst;
  StartRoadID:=rsNodes.Fields[RS_NODE_ROADID].Value;
  StartNodeID:=rsNodes.Fields[RS_NODE_ORDERNO].Value;
  FinishRoadID:=rsNodes.Fields[RS_NODE_ROADID].Value;
  FinishNodeID:=rsNodes.Fields[RS_NODE_ORDERNO].Value;

  DStartMin:= Distance(lat1,lon1,
                       arRoads[StartRoadID].Vertex[StartNodeID].Lat,arRoads[StartRoadID].Vertex[StartNodeID].Lon
                       {rsNodes.Fields[RS_NODE_LAT].Value,rsNodes.Fields[RS_NODE_LON].Value});

  DFinishMin:=Distance(lat2,lon2,
                       arRoads[FinishRoadID].Vertex[FinishNodeID].Lat,arRoads[FinishRoadID].Vertex[FinishNodeID].Lon
                       {rsNodes.Fields[RS_NODE_LAT].Value,rsNodes.Fields[RS_NODE_LON].Value});

  repeat
    CurrentRoadID:=rsNodes.Fields[RS_NODE_ROADID].Value;
    CurrentNodeID:=rsNodes.Fields[RS_NODE_ORDERNO].Value;

    DStart:= Distance(lat1,lon1,
                      arRoads[CurrentRoadID].Vertex[CurrentNodeID].Lat,
                      arRoads[CurrentRoadID].Vertex[CurrentNodeID].Lon);
    if DStart<DStartMin then
      begin
        StartRoadID:=CurrentRoadID;
        StartNodeID:=CurrentNodeID;
        DStartMin:=DStart;
      end;

    DFinish:=Distance(lat2,lon2,
                      arRoads[CurrentRoadID].Vertex[CurrentNodeID].Lat,
                      arRoads[CurrentRoadID].Vertex[CurrentNodeID].Lon);
    if DFinish<DFinishMin then
      begin
        FinishRoadID:=CurrentRoadID;
        FinishNodeID:=CurrentNodeID;
        DFinishMin:=DFinish;
      end;

    rsNodes.MoveNext;
  until rsNodes.EOF;

  aRoute:=CreateRoute(StartRoadID,StartNodeID,FinishRoadID,FinishNodeID);

   Result:=aRoute;


End;



end.
