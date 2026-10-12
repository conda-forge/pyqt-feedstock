# pyqtSlot(result=...) return types must be registered in the meta-object.
# They are silently registered as void when PyQt6 runs against a Qt patch release
# with a different private QMetaObjectBuilder ABI (see #201).
from PyQt6.QtCore import QObject, pyqtSlot


class Settings(QObject):
    @pyqtSlot(str, result=bool)
    def contains(self, key):
        return True

    @pyqtSlot(result='QStringList')
    def all_keys(self):
        return []


for _ in range(100):
    mo = Settings().metaObject()
    for sig, expected in ((b'contains(QString)', 'bool'), (b'all_keys()', 'QStringList')):
        actual = mo.method(mo.indexOfMethod(sig)).typeName()
        assert actual == expected, f"{sig.decode()}: {actual} != {expected}"
print("slot result types OK")
