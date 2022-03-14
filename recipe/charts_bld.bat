pushd pyqt_charts

set PATH=%cd%\jom;%PATH%
set PATH=%LIBRARY_INC%;%PATH%

call sip-build ^
--verbose ^
--no-make

pushd build

jom
jom install
