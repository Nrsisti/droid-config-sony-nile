@echo off

:: This is simple windows flashing script for Sony Xperia XA2 device
:: This script is using fastboot to flash which differs from the factory method.

set tmpflashfile=tmpfile.txt
set emmawebsite=https://developer.sony.com/develop/open-devices/get-started/flash-tool/download-flash-tool/
set unlockwebsite=https://developer.sony.com/develop/open-devices/get-started/unlock-bootloader/
set oemblobwebsite=https://developer.sony.com/file/download/software-binaries-for-aosp-oreo-android-8-1-kernel-4-4-nile/
set fastbootkillretval=0
set serialnumbers=

echo(
echo This is a Windows flashing script for Sony Xperia XA2 device.
echo(
echo Power on the device in fastboot mode, by doing the following:
echo 1. Turn off your Xperia.
echo 2. Connect one end of a USB cable to your PC.
echo 3. While holding the volume up button pressed, connect the other end of
echo    the USB cable to your Xperia.
echo 4. After this you should see the blue LED lit on Xperia, and it will be
echo    ready for flashing
echo(
pause
call :sleep 3

:: Ensure that tools have valid md5sum before using them
@call :md5sum AdbWinApi.dll
@call :md5sum AdbWinUsbApi.dll
@call :md5sum fastboot.exe
@call :md5sum flash-on-windows.bat

set fastbootcmd_no_device=fastboot.exe
set current_device=

echo(
echo Searching a compatible device...

:: Ensure that we are flashing right device
:: H4113 - Xperia XA2 Dual SIM

@call :devices

if not "%serialnumbers%" == "" GOTO no_error_serialnumbers

:: If fastboot devices does not list any devices, then we cannot flash.
echo(
echo We did not find any devices with fastboot.
echo(
echo The device is not properly connected to your computer or
echo you might be missing the required windows fastboot drivers for your device.
echo(
echo Go to the Windows Device Manager and verify that the fastboot driver for the
echo device is properly installed.
echo(
pause
exit /b 1

:no_error_serialnumbers


if "%serialnumbers%" == "%serialnumbers: =%" GOTO no_multiple_serialnumbers

echo(
echo It seems that there are multiple compatible devices connected in fastboot mode.
echo Make sure only the device that you intend to flash is connected.
pause
exit /b 1

:no_multiple_serialnumbers

set current_device=%serialnumbers%

if not [%current_device%] == [] GOTO no_error_product

echo(
echo The DEVICE this flashing script is meant for WAS NOT FOUND!
echo(
echo This script found following device:
type %tmpflashfile%
pause
exit /b 1

:no_error_product

:: Now we know which device we need to flash
set fastbootcmd=%fastbootcmd_no_device% -s %current_device%

:: Check that device has been unlocked
@call :getvar secure
findstr /R /C:"secure: no" %tmpflashfile% >NUL 2>NUL
if not errorlevel 1 GOTO no_error_unlock
echo(
echo This device has not been unlocked for the flashing. Please follow the
echo instructions how to unlock your device at the following webpage:
echo %unlockwebsite%
echo(
echo Press enter to open browser with the webpage.
echo(
pause
start "" %unlockwebsite%
exit /b 1

:no_error_unlock

echo(
echo The device is unlocked for the flashing process. Continuing..

echo(
del %tmpflashfile% >NUL 2>NUL
setlocal EnableDelayedExpansion

:: Find the blob image. Make sure there's only one.
for /r %%f in (*_nile.img) do (
if not defined blobfilename (
:: Take only the filename and strip out the path which otherwise is there.
:: This is to make sure that we do not face issues later with e.g. spaces in the path etc.
set blobfilename=%%~nxf
) else (
echo(
echo More than one Sony Vendor image was found in this directory.
echo Please remove any additional files ^(*_nile.img^).
echo(
exit /b 1
)
)

echo(
echo Found '%blobfilename%' that will be used as vendor image. Continuing..

:: Bail out if we don't have a blob image
if not defined blobfilename (
echo(
echo The Sony Vendor partition image was not found in the current
echo directory. Please download it from %oemblobwebsite%
echo and unzip it into this directory.
echo(
echo Press enter to open the browser with the webpage.
echo(
pause
start "" %oemblobwebsite%
exit /b 1
)

:: We want to print the fastboot commands so user can see what actually
:: happens when flashing is done.
@echo on

@call :fastboot flash boot hybris-boot.img
@call :fastboot flash system_b fimage.img001
@call :fastboot flash userdata sailfish.img001
@call :fastboot flash oem %blobfilename%

:: NOTE: Do not reboot here as the battery might not be in the device
:: and in such situation we should not reboot the device.
@echo(
@echo Flashing completed.
@echo(
@echo Remove the USB cable and bootup the device by pressing powerkey.
@echo(
@pause

@exit /b 0

:: Function to sleep X seconds
:sleep
:: @echo "Waiting %*s.."
ping 127.0.0.1 -n %* >NUL
@exit /b 0

:devices
for /f "tokens=1" %%f in ('fastboot devices') do call :new_serialno_found %%f
@exit /b 0

:new_serialno_found
set serialno=%1
if "%serialnumbers%" == "" (
set serialnumbers=%serialno%
) else (
set "serialnumbers=%serialno% %serialnumbers%"
)
@exit /b 0

:getvar
del %tmpflashfile% >NUL 2>NUL

start /b cmd /c %fastbootcmd% getvar %* 2^>^&1 ^| find "%*:" ^> %tmpflashfile%
call :sleep 3
:: In case the device is not online, fastboot will just hang forever thus
:: kill it here so the script ends at some point.
taskkill /im fastboot.exe /f >NUL 2>NUL
set fastbootkillretval=%errorlevel%
@exit /b 0

:md5sum
@set md5sumold=
:: Before flashing calculate md5sum to ensure file is not corrupted, so for each line in md5.lst do
@for /f %%i in ('findstr %~1 md5.lst') do @set md5sumold=%%i
:: Some files e.g. oem partition image is not part of md5.lst so skip checking md5sum for that file
@if [%md5sumold%] == [] goto :skip_md5sum
:: We want to take the second line of output from CertUtil, if you know better way let me know :)
:: delims= is needed for this to work on windows 8
@for /f "skip=1 tokens=1 delims=" %%i in ('CertUtil -hashfile "%~1" MD5') do @set md5sumnew=%%i && goto :file_break
:file_break
:: Drop all spaces from the md5sumnew as the format provided by CertUtil is two chars space two chars..
@set md5sumnew=%md5sumnew: =%
:: Drop everything after the first space in md5sumold
@set "md5sumold=%md5sumold: ="&rem %
@IF NOT "%md5sumnew%" == "%md5sumold%" (
  @echo(
  @echo MD5SUM '%md5sumnew%' of file '%~1' does not match to '%md5sumold%' found from md5.lst.
  @call :exitflashfail
)
@echo MD5SUM '%md5sumnew%' match for file '%~1'.
:skip_md5sum
@exit /b 0

:: Function to call fastboot command with error checking
:fastboot
:: When flashing check md5sum of files
@IF "%~1" == "flash" (
  @call :md5sum %~3
)
%fastbootcmd% %*
@IF "%ERRORLEVEL%" == "1" (
  @echo(
  @echo ERROR: Failed to execute '%fastbootcmd% %*'.
  @call :exitflashfail
)
@exit /b 0

:exitflashfail
@echo(
@echo FLASHING FAILED!
@echo(
@echo Please go to https://together.jolla.com/ and ask for guidance.
@echo(
@pause
@exit 1
@exit /b 0

