@echo off

SET LOG=d:\OSM\osm_data\log.txt
echo ������ �������� %DATE%_%TIME% >>%LOG%

rem - ����������� ����, ������� ������ ��������� �� ������ ����
cscript main.vbs

echo ��������� �������� %DATE%_%TIME% >>%LOG%

rem - update the list of maps
rem curl -T "history.txt" -u *****:***** ftp://gis-lab.info/history.txt
rem curl -T "log.txt" -u *****:***** ftp://gis-lab.info/log.txt
SET LOG=




