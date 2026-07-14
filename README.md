# Prokera Filling Pump

Control station for a Prokera filling pump using an Arduino UNO, a CL42T stepper driver, a physical press switch, and a Windows graphical control panel.

## Version 2.0.0

Version 2 adds a silent launcher:

- `windows-app/Run_UnoPumpControl_Silent.vbs`

Use this launcher when you want only the button window to appear, without the PowerShell console.

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

If the CL42T is enabled by default, you can test with `ENA+` and `ENA-` disconnected first.

Do not use 24V directly with Arduino pins. For direct UNO-to-CL42T wiring, use 5V on `PUL+`, `DIR+`, and `ENA+`.

## How To Use

1. Open Arduino IDE.
2. Upload `firmware/Uno_Pump_Control/Uno_Pump_Control.ino` to the Arduino UNO.
3. Close Arduino IDE Serial Monitor.
4. Connect the UNO by USB.
5. Run `windows-app/Run_UnoPumpControl_Silent.vbs`.
6. Select the UNO COM port and press `Connect`.
7. Set `Steps` and `Speed us`.
8. Press the large `RUN` button to run with the values shown on screen.
9. Use `Save` only when you want to save values in the UNO without running the pump.

## Serial Commands

Baudrate: `115200`

```text
GET
SET STEPS 32000
SET SPEED 210
RUN
RUN 32000 210
STOP
PING
```
