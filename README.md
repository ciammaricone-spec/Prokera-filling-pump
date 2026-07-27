# Prokera Filling Pump

Control station for a Prokera filling pump using Arduino controllers, a CL42T stepper driver, a physical press switch, and a Windows graphical control panel.

## Version 3.1.0

Version 3.1 updates the UI branding and keeps the v3 purge behavior.

Active UNO sketch/app label:

`V3-0 Peristaltic filling by G.C.`

Active Nano R4 sketch/app label:

`V3-0 Nano R4 Peristaltic filling by G.C.`

Includes:

- PURGE app button: fixed 15000 steps using the current speed.
- Physical press switch short press: normal run.
- Physical press switch long press, 3 seconds or more: purge run.
- Silent VBS launcher so the PowerShell console stays hidden.
- Updated title/header/signature text.
- Nano R4 firmware and Windows app package.
- Pharmaceutical laboratory style technical manual.

The purge run does not overwrite the normal configured step count.

## Contents

- `firmware/Uno_Pump_Control/Uno_Pump_Control.ino` - Arduino UNO firmware.
- `windows-app/UnoPumpControl.ps1` - UNO Windows graphical control panel.
- `windows-app/Run_UnoPumpControl.bat` - UNO double-click launcher with PowerShell console.
- `windows-app/Run_UnoPumpControl_Silent.vbs` - UNO double-click launcher without PowerShell console.
- `firmware/Nano_R4_Pump_Control/Nano_R4_Pump_Control.ino` - Arduino Nano R4 firmware.
- `windows-app/Nano_R4_Pump_Control/` - Nano R4 Windows app, launchers, and app README.
- `docs/technical-manual/` - Nano R4 pharmaceutical laboratory style technical manual.

## Arduino Nano R4 Version

Nano R4 defaults:

- Normal run: `32000` steps.
- Purge: `15000` fixed steps.
- Speed: `210 us`.
- USB serial: `115200`.
- Press switch short press: normal run.
- Press switch long press, 3 seconds or more: purge run.

Nano R4 CL42T common-anode wiring:

| CL42T | Arduino Nano R4 |
| --- | --- |
| `PUL+` | regulated `5V` |
| `PUL-` | `A5` |
| `DIR+` | regulated `5V` |
| `DIR-` | `D2` |
| `ENA+` | regulated `5V`, optional |
| `ENA-` | `A1`, optional |
| Press switch | `A2` and `GND` |

Nano R4 use:

1. Open Arduino IDE.
2. Upload `firmware/Nano_R4_Pump_Control/Nano_R4_Pump_Control.ino` to the Arduino Nano R4.
3. Close Arduino IDE Serial Monitor.
4. Connect the Nano R4 by USB.
5. Run `windows-app/Nano_R4_Pump_Control/Run_NanoR4PumpControl_Silent.vbs`.
6. Select the Nano R4 COM port and press `Connect`.
7. Press `Read`, set `Steps` and `Speed us` if needed, then use `RUN`, `PURGE`, or the physical switch.

## Arduino UNO Version

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

UNO use:

1. Open Arduino IDE.
2. Upload `firmware/Uno_Pump_Control/Uno_Pump_Control.ino` to the Arduino UNO.
3. Close Arduino IDE Serial Monitor.
4. Connect the UNO by USB.
5. Run `windows-app/Run_UnoPumpControl_Silent.vbs`.
6. Select the UNO COM port and press `Connect`.
7. Set `Steps` and `Speed us`.
8. Press `RUN` for a normal run.
9. Press `PURGE` for 15000 fixed steps.

## Safety Note

Do not use 24V directly with Arduino pins. For direct Arduino-to-CL42T wiring, use regulated 5V on `PUL+`, `DIR+`, and `ENA+`.

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
