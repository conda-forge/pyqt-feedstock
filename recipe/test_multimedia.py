"""Smoke test for the pyqt6-multimedia package."""
import os
import sys

os.environ.setdefault("QT_QPA_PLATFORM", "offscreen")

from PyQt6.QtWidgets import QApplication
from PyQt6.QtMultimedia import QAudioFormat, QMediaFormat, QMediaPlayer
from PyQt6.QtMultimediaWidgets import QVideoWidget

app = QApplication(sys.argv)

fmt = QAudioFormat()
fmt.setSampleRate(44100)
assert fmt.sampleRate() == 44100

# Constructing a player loads the Qt multimedia backend plugin.
player = QMediaPlayer()
widget = QVideoWidget()
player.setVideoOutput(widget)
print("supported file formats:", len(QMediaFormat().supportedFileFormats(QMediaFormat.ConversionMode.Decode)))

print("All checks passed.")
