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
  
  //echo "<html>";
  //echo "download ".$download;
  //echo "</html>";
  $file=fopen("download_log.txt","a+"); //book1.txt - ��� ��� �����, � ������� ����� ��������� ���������� �������
  flock($file,LOCK_EX); 
  fwrite($file,$download."|".date("Y-m-d H:i:s")."\n"); 
  flock($file,LOCK_UN); 
  fclose($file); 
  
}	
?>