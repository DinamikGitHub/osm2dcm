Attribute VB_Name = "mdlProcessOsmFile"
Option Explicit
' ��������� �����
'
Const WAY_MAPID = "MapID"
Const WAY_WAYID = "WayID"
Const WAY_HIGHWAY = "Highway"
Const WAY_NAME = "Name"
Const WAY_REF = "Ref"
Const WAY_CURRENTVERSION = "CurrentVersion"
Const WAY_CHANGEDESCRIPTION = "ChangeDescription"
Const WAY_CHANGEUSER = "ChangeUser"
Const WAY_CHANGEDATE = "ChangeDate"
Const WAY_APPROVEDVERSION = "ApprovedVersion"
Const WAY_APPROVEDUSER = "ApprovedUser"
Const WAY_APPROVEDDATE = "ApprovedDate"
Const WAY_UPDATEDATE = "UpdateDate"

Public strConnectionString As String
Public strOSMPath As String

Private Sub LoadData(strMapID As String, rsWays As ADODB.Recordset, rsNodes As ADODB.Recordset, blnStructureOnly)
  
  Dim objCon As ADODB.Connection
  Dim strSelect As String
  Set objCon = New ADODB.Connection
  objCon.Open strConnectionString
  
  
  Set rsWays = New ADODB.Recordset
  rsWays.CursorType = adOpenStatic
  rsWays.CursorLocation = adUseClient
  
  strSelect = " where " & WAY_MAPID & " = '" & strMapID & "'"
  If blnStructureOnly Then
    strSelect = strSelect + " and 1=0"
  End If
  
  rsWays.Open "Select * from WayLog " & strSelect, objCon, adOpenStatic, adLockBatchOptimistic, adCmdText

  Set rsNodes = New ADODB.Recordset
  rsNodes.CursorType = adOpenStatic
  rsNodes.CursorLocation = adUseClient
  rsNodes.Open "Select * from Nodes", objCon, adOpenStatic, adLockBatchOptimistic, adCmdText

End Sub

Private Function ProcessOsmFile(strMapID As String, rsWays As ADODB.Recordset, rsNodes As ADODB.Recordset, strFileName As String)
  Dim textline As String
  Dim clsXMLNode As zXMLNode
  Dim dtDate As Date
  Dim strWayId As String
  Dim intVersion As String
  Dim strUser As String
  Dim strHighway As String
  Dim strRef As String
  Dim strName As String
  
  Dim NodeCollection As Collection
  
  
On Error GoTo finalize
  PrintToLog "Processing file: " & strFileName
  Open strFileName For Input As #1
  Do While EOF(1) <> True
    
    Line Input #1, textline
    Set clsXMLNode = New zXMLNode
    clsXMLNode.ParseNode textline
    
    If clsXMLNode.Name = "way" Then
      '�������� ��������
      
      strWayId = clsXMLNode.GetAttributeValue("id")
      dtDate = clsXMLNode.dtTimeStamp
      strUser = clsXMLNode.GetAttributeValue("user")
      intVersion = clsXMLNode.GetAttributeValue("version")
      
      strRef = ""
      strHighway = ""
      strName = ""
      
      Set NodeCollection = New Collection
      
      Do
        Line Input #1, textline
        Set clsXMLNode = New zXMLNode
        clsXMLNode.ParseNode textline
        
        If clsXMLNode.Name = "nd" Then
          NodeCollection.Add clsXMLNode.GetAttributeValue("ref")
        End If
        
        
        If clsXMLNode.Name = "tag" Then
           
          '�� ��������
          ' - ��������� �� ���������
          If clsXMLNode.GetAttributeValue("k") = "name" Then
            strName = clsXMLNode.GetAttributeValue("v")
          End If
          
          If clsXMLNode.GetAttributeValue("k") = "ref" Then
            strRef = clsXMLNode.GetAttributeValue("v")
          End If
          
          If clsXMLNode.GetAttributeValue("k") = "highway" Then
            strHighway = clsXMLNode.GetAttributeValue("v")
          End If
        
        End If
              
      Loop Until clsXMLNode.Name = "/way"
    
      If (strHighway = "motorway") Or (strHighway = "motorway_link") Or _
         (strHighway = "trunk") Or (strHighway = "trunk_link") Or _
         (strHighway = "primary") Or (strHighway = "primary_link") Then
        '��� � ����� ���� ������
        rsWays.AddNew
        rsWays(WAY_MAPID).Value = strMapID
        rsWays(WAY_WAYID).Value = strWayId
        rsWays(WAY_HIGHWAY).Value = strHighway
        rsWays(WAY_REF).Value = strRef
        rsWays(WAY_NAME) = strName
        rsWays(WAY_CHANGEDATE).Value = dtDate
        rsWays(WAY_CHANGEUSER).Value = strUser
        rsWays(WAY_CURRENTVERSION).Value = intVersion
        rsWays.Update
        
      End If
    End If
    
  Loop
  
ProcessOsmFile = True
finalize:
  Close #1
  If Err.Number <> 0 Then
    Err.Raise vbObjectError, "ProcessOsmFile", Err.Description
   End If
End Function
Private Sub CompareVersions(rsWays As ADODB.Recordset, rsWaysNew As ADODB.Recordset)
  Dim dtUpdateDate As Date
  
  dtUpdateDate = Now()
  
  rsWaysNew.MoveFirst
  Do While Not rsWaysNew.EOF
    rsWays.Filter = WAY_WAYID & "='" & rsWaysNew(WAY_WAYID).Value & "'"
    If rsWays.RecordCount = 0 Then
      '��� ����� ����������� ���
      rsWays.AddNew
        
      rsWays(WAY_MAPID).Value = rsWaysNew(WAY_MAPID).Value
      rsWays(WAY_WAYID).Value = rsWaysNew(WAY_WAYID).Value
      rsWays(WAY_HIGHWAY).Value = rsWaysNew(WAY_HIGHWAY).Value
      rsWays(WAY_REF).Value = rsWaysNew(WAY_REF).Value
      rsWays(WAY_NAME).Value = rsWaysNew(WAY_NAME).Value
      rsWays(WAY_CHANGEDATE).Value = rsWaysNew(WAY_CHANGEDATE).Value
      rsWays(WAY_CHANGEUSER).Value = rsWaysNew(WAY_CHANGEUSER).Value
      rsWays(WAY_CURRENTVERSION).Value = rsWaysNew(WAY_CURRENTVERSION).Value
      
      '���� � ������� ���������� � ������
      If rsWays(WAY_CURRENTVERSION).Value = 1 Then
       rsWays(WAY_CHANGEDESCRIPTION).Value = "������"
      Else
        rsWays(WAY_CHANGEDESCRIPTION).Value = "�������� � ������"
      End If
      
      '��������� ���������
      rsWays(WAY_APPROVEDDATE).Value = Null
      rsWays(WAY_APPROVEDUSER).Value = Null
      rsWays(WAY_APPROVEDVERSION).Value = Null
      
      rsWays(WAY_UPDATEDATE).Value = dtUpdateDate
      rsWays.Update
    Else
      '��� ������������ (����������)  ���
      If rsWays(WAY_CURRENTVERSION).Value <> rsWaysNew(WAY_CURRENTVERSION).Value Then
        rsWays(WAY_MAPID).Value = rsWaysNew(WAY_MAPID).Value
        rsWays(WAY_WAYID).Value = rsWaysNew(WAY_WAYID).Value
        rsWays(WAY_HIGHWAY).Value = rsWaysNew(WAY_HIGHWAY).Value
        rsWays(WAY_REF).Value = rsWaysNew(WAY_REF).Value
        rsWays(WAY_NAME).Value = rsWaysNew(WAY_NAME).Value
        rsWays(WAY_CHANGEDATE).Value = rsWaysNew(WAY_CHANGEDATE).Value
        rsWays(WAY_CHANGEUSER).Value = rsWaysNew(WAY_CHANGEUSER).Value
        rsWays(WAY_CURRENTVERSION).Value = rsWaysNew(WAY_CURRENTVERSION).Value
        
        '���� � ������� ���������� � ������
        rsWays(WAY_CHANGEDESCRIPTION).Value = "�������"
        rsWays(WAY_UPDATEDATE).Value = dtUpdateDate
        
        '��������� ���������
        rsWays(WAY_APPROVEDDATE).Value = Null
        rsWays(WAY_APPROVEDUSER).Value = Null
        rsWays(WAY_APPROVEDVERSION).Value = Null
        
        rsWays.Update
      Else
        '��� �� �������, �� ���� ��������� �������� ��� ����� ���������������
        rsWays(WAY_UPDATEDATE).Value = dtUpdateDate
      End If
    End If
    rsWaysNew.MoveNext
  Loop
  
  rsWays.Filter = WAY_UPDATEDATE & "<'" & dtUpdateDate & "'"
  '��� ���, ������� ��� � ����� �����
  Do While Not rsWays.EOF
    If rsWays(WAY_CURRENTVERSION).Value <> 0 Then
      rsWays(WAY_CURRENTVERSION).Value = 0
      
      '���� � ������ �������� �� �� �������� ������� �������� �� �����
      rsWays(WAY_CHANGEDATE).Value = dtUpdateDate
      rsWays(WAY_CHANGEUSER).Value = "???"
          
      '���� � ������� ���������� � ������
      rsWays(WAY_CHANGEDESCRIPTION).Value = "������"
      
      rsWays(WAY_APPROVEDDATE).Value = Null
      rsWays(WAY_APPROVEDUSER).Value = Null
      rsWays(WAY_APPROVEDVERSION).Value = Null
      
    Else
      ' ���� �� ��� �����, ��� ���  ������, ������ ������ �� ����
    End If
    rsWays(WAY_UPDATEDATE).Value = dtUpdateDate
    
    rsWays.MoveNext
  Loop
  
  rsWays.Filter = adFilterNone
End Sub

Public Sub ProcessMap(MapCode As String)
Dim rsNodes As ADODB.Recordset
Dim rsWays As ADODB.Recordset

Dim rsNodesNew As ADODB.Recordset
Dim rsWaysNew As ADODB.Recordset
 
  
  '�������� ������ �� ����
  LoadData MapCode, rsWays, rsNodes, False
  LoadData MapCode, rsWaysNew, rsNodesNew, True

  '�������� ������ �� ���-�����

  ProcessOsmFile MapCode, rsWaysNew, rsNodesNew, strOSMPath & "\" & MapCode & "\final.osm"
  
  CompareVersions rsWays, rsWaysNew

  rsWays.UpdateBatch adAffectAll


End Sub


