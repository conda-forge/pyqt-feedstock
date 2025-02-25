%PYTHON% %RECIPE_DIR%/check_imports.py

if not exist %PREFIX%\\Scripts\\pyuic6.exe (echo "FATAL: Failed to find %PREFIX%\\Scripts\\pyuic6.exe" && exit 1)

pyuic6 --version
