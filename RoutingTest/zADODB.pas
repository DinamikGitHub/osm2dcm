unit zADODB;

interface
uses ComObj, ADOInt,ActiveX;

//����������� ���� Recordset
type Recordset=_Recordset;

implementation

initialization
  CoInitializeEx(nil, COINIT_MULTITHREADED);

finalization
  CoUninitialize();
end.
