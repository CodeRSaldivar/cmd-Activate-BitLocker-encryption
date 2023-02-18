@echo off
cls

SET test /A = "N/A"
FOR /F "tokens=3 delims= " %%A in ('manage-bde -status %systemdrive% ^| findstr "    Encryption Method:"') do (
	echo %%A
	SET test = %%A
	IF "%%A"=="None" goto :notEncrypted
)

echo The disk is already encrypted

goto :eof

:notEncrypted

echo.
powershell Initialize-Tpm

::Validate if win32_tpm IsEnabled
::wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue

FOR /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue ^| findstr "TRUE"') do (
	IF "%%A"=="TRUE" goto :CheckVersion
)

echo.
echo TPM needs to be activated on the BIOS, there are a number of different names for the TPM setting you are looking for could be listed as, including:
echo.
echo PTT
echo TPM Device
echo Trusted Platform Module
echo TPM Device Selection
echo AMD fTPM Switch

GOTO :eof

:CheckVersion
::Validate if win32_tpm is version 2.0

FOR /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get SpecVersion ^| find /C "2.0, "') do (
	IF "%%A"=="1" goto :IsEnabled
)

echo TPM is not version 2.0

GOTO :eof

:IsEnabled
::Validate if win32_tpm IsActivated

FOR /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsActivated_InitialValue ^| findstr "TRUE"') do (
	IF "%%A"=="TRUE" goto :IsActivated
)

echo TPM is not activated

GOTO :eof

:IsActivated
::Validate if win32_tpm IsOwned
::wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsOwned_InitialValue

FOR /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsActivated_InitialValue ^| findstr "TRUE"') do (
	IF "%%A"=="TRUE" goto :Encrypt
)

echo TPM does not report an owner

GOTO :eof

:Encrypt

::timeout /T 90

IF EXIST "\\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt" ( GOTO :eof )

::FOR /F %%A in ('wmic /namespace:\\root\cimv2\security\microsofttpm path win32_tpm get IsEnabled_InitialValue ^| findstr "TRUE"') do (
::	IF NOT "%%A"=="TRUE" ( powershell Initialize-Tpm > NUL )
::)

manage-bde -protectors -disable %systemdrive%
::bcdedit /set {default} recoveryenabled No
::bcdedit /set {default} bootstatuspolicy ignoreallfailures
manage-bde -protectors -delete %systemdrive% -type RecoveryPassword
manage-bde -protectors -add %systemdrive% -RecoveryPassword

::for /F "tokens=2 delims=: " %%A in ('manage-bde -protectors -get C: -type recoverypassword ^| findstr "       ID:"') do (
::	manage-bde -protectors -adbackup %systemdrive% -id %%A
::)

:Save-Recovery-Key
manage-bde -protectors -get c: > \\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt
IF NOT EXIST "\\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt" ( GOTO :Save-Recovery-Key )

echo.>> \\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt
echo Hostname >> \\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt
echo %COMPUTERNAME% >> \\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt
echo.>> \\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt
wmic bios get serialnumber /format:table | find /v "" >> \\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt
ipconfig /all >> \\192.168.0.3\scripts\BitLocker-Recovery-Keys\%COMPUTERNAME%.txt

manage-bde -protectors -enable %systemdrive%
manage-bde -on %systemdrive% -SkipHardwareTest
echo.
manage-bde -status

GOTO :eof

::References
::https://www.prajwaldesai.com/check-tpm-status-command-line/
::https://winbuzzer.com/2021/07/22/how-to-check-if-your-windows-10-pc-has-a-tpm-chip-xcxwbt/
::https://techdirectarchive.com/2022/02/03/how-to-determine-if-tpm-is-present-and-how-to-enable-tpm-in-the-bios-via-the-command-prompt/
::https://www.intowindows.com/3-ways-to-check-tpm-version-in-windows-10-11/
::https://www.groovypost.com/howto/download-and-install-windows-11/
::https://social.technet.microsoft.com/Forums/en-US/3ec0e6e8-4d12-4d1f-9d1f-e27e5c8cca91/enable-bitlocker-and-restore-recover-keys-to-ad?forum=winserverGP
::http://kb.mit.edu/confluence/display/istcontrib/Manually+Backup+BitLocker+Recovery+Key+to+AD
::https://social.technet.microsoft.com/Forums/windows/en-US/d720600f-c7a0-4693-8d72-2c8a4ca3bc89/why-does-managebde-recoverykey-need-a-parameter-if-my-gpo-says-to-store-the-key-in-ad?forum=win10itprosecurity
::https://recoverit.wondershare.com/harddrive-recovery/how-to-enable-bitlocker-windows.html
::https://community.spiceworks.com/topic/2182258-script-to-enable-bitlocker-windows-10
::https://www.bullfrag.com/how-to-enable-and-configure-bitlocker-in-windows-using-cmd-commands/
::https://community.spiceworks.com/topic/2042349-how-to-script-to-simply-enable-bitlocker-on-windows-8-1-and-10
::https://iboysoft.com/bitlocker/turn-off-bitlocker-windows.html
::https://www.windowscentral.com/how-suspend-bitlocker-encryption-perform-system-changes-windows-10
::https://allthings.how/how-to-enable-or-turn-off-bitlocker-on-windows-11/
::https://www.partitionwizard.com/disk-recovery/suspend-bitlocker.html
::https://www.itechtics.com/manage-bitlocker-command-line/
::https://superuser.com/questions/1590289/how-to-enable-bitlocker-system-drive-encryption-on-windows-10-home
::https://www.top-password.com/blog/use-gpo-to-save-bitlocker-recovery-key-in-active-directory/
::https://learn.microsoft.com/en-us/previous-versions/windows/it-pro/windows-server-2012-r2-and-2012/ff829848(v=ws.11)
::https://geekshangout.com/enabling-bitlocker-from-command-line/
::https://www.dell.com/support/kbdoc/en-in/000125409/how-to-enable-or-disable-bitlocker-with-tpm-in-windows#:~:text=Click%20the%20Windows%20Start%20button,bde%20%2Dstatus%20and%20press%20Enter.
