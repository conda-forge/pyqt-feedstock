pushd pyqt
copy LICENSE ..

set PATH=%cd%\jom;%PATH%
set PATH=%LIBRARY_INC%;%PATH%

call sip-build ^
--verbose ^
--confirm-license ^
--disable QtNfc ^
--no-make

pushd build

jom
jom install
