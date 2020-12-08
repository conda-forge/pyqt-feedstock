:: QtNfc fails so we disable it for now.
:: Qt5Nfc.lib(Qt5Nfc.dll) : error LNK2005: "public: __thiscall QList<class QNdefRecord>::QList<class QNdefRecord>(class QList<class QNdefRecord> const &)" (??0?$QList@VQNdefRecord@@@@QAE@ABV0@@Z) already defined in sipQtNfcQList0100QNdefRecord.obj
:: Qt5Nfc.lib(Qt5Nfc.dll) : error LNK2005: "public: __thiscall QList<class QNdefRecord>::~QList<class QNdefRecord>(void)" (??1?$QList@VQNdefRecord@@@@QAE@XZ) already defined in sipQtNfcQList0100QNdefRecord.obj
:: Qt5Nfc.lib(Qt5Nfc.dll) : error LNK2005: "public: class QList<class QNdefRecord> & __thiscall QList<class QNdefRecord>::operator=(class QList<class QNdefRecord> const &)" (??4?$QList@VQNdefRecord@@@@QAEAAV0@ABV0@@Z) already defined in sipQtNfcQList0100QNdefRecord.obj
::    Creating library release\QtNfc.lib and object release\QtNfc.exp
:: release\QtNfc.dll : fatal error LNK1169: one or more multiply defined symbols found


setlocal EnableDelayedExpansion
set "INCLUDE=%LIBRARY_INC%;%INCLUDE%"
set "LIB=%LIBRARY_LIB%;%LIB%"


:: install PyQtWebEngine
echo.
echo ************** start building PyQtWebEngine **************
echo.
cd pyqtwebengine

%PYTHON% configure.py
if errorlevel 1 exit 1

nmake
if errorlevel 1 exit 1

nmake install
if errorlevel 1 exit 1

cd ..
echo.
echo ****************** built PyQtWebEngine *******************
echo.
