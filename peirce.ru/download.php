<?php
// ������� �� ������� �����: 
$download=$_GET['mapid'];
if (empty($download))
 {
  header("location: http://http://peirce.gis-lab.info"); //����� ���������� ���� � �����, ������� ����� �������
}
else 
{
  //header("location: http://osm.interlan.ru/cg_maps/$download.rar"); //����� ���������� ���� � �����, ������� ����� �������
  header("location: http://peirce.osm.rambler.ru/cg_maps/$download.rar"); //����� ���������� ���� � �����, ������� ����� �������
  
  
}	
?>