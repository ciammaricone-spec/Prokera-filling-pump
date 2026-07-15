# Prokera Filling Pump

Control station for a Prokera filling pump using an Arduino UNO, a CL42T stepper driver, a physical press switch, and a Windows graphical control panel.

## Version 3.0.0

Version 3 adds purge controls:

- `PURGE` app button: fixed 15000 steps using the current speed.
- Physical press switch short press: normal run.
- Physical press switch long press, 3 seconds or more: purge run.

The purge run does not overwrite the normal configured step count.

## Contents

- `firmware/Uno_Pump_Control/Uno_Pump_Control.ino` - Arduino UNO firmware
- `windows-app/UnoPumpControl.ps1` - Windows graphical control panel
- `windows-app/Run_UnoPumpControl.bat` - double-click launcher with PowerShell console
- `windows-app/Run_UnoPumpControl_Silent.vbs` - double-click launcher without PowerShell console

## CL42T Wiring With Arduino UNO

Use 5V for the CL42T signal inputs when wiring directly to the UNO.

| CL42T | Arduino UNO |
| --- | --- |
| `PUL+` | `5V` |
| `PUL-` | `A5` |
| `DIR+` | `5V` |
| `DIR-` | `D2` |
| `ENA+` | `5V` |
| `ENA-` | `A1` |
| Press switch | `A3` and `GND` |

Do not use 24V directly with Arduino pins. For direct UNO-to-CL42T wiring, use 5V on `PUL+`, `DIR+`, and `ENA+`.

## How To Use

1. Open Arduino IDE.
2. Upload `firmware/Uno_Pump_Control/Uno_Pump_Control.ino` to the Arduino UNO.
3. Close Arduino IDE Serial Monitor.
4. Connect the UNO by USB.
5. Run `windows-app/Run_UnoPumpControl_Silent.vbs`.
6. Select the UNO COM port and press `Connect`.
7. Set `Steps` and `Speed us`.
8. Press `RUN` for a normal run.
9. Press `PURGE` for 15000 fixed steps.

## Physical Press Switch

- Less than 3 seconds: normal run.
- 3 seconds or more: purge, fixed 15000 steps.
- The action starts when the switch is released.

## Serial Commands

Baudrate: `115200`

```text
GET
SET STEPS 32000
SET SPEED 210
RUN
RUN 32000 210
PURGE
STOP
PING
```
