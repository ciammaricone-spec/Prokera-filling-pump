# Prokera Filling Pump

Control station for a Prokera filling pump using an Arduino Nano R4, a CL42T stepper driver, a physical press switch, and a Windows graphical control panel.

## Active Version

Active Nano R4 sketch/app label:

`V3-0 Nano R4 Peristaltic filling by G.C.`

Includes:

- Arduino Nano R4 firmware.
- Windows graphical pump control app.
- RUN, PURGE, STOP, Save, Read, and Clear Log controls.
- USB RUN/PURGE commands work when the Windows app is connected.
- Physical press switch short press: normal run.
- Physical press switch long press, 3 seconds or more: purge run.
- Silent VBS launcher so the PowerShell console stays hidden.
- Pharmaceutical laboratory style technical manual.

The purge run does not overwrite the normal configured step count.

## Contents

- `firmware/Nano_R4_Pump_Control/Nano_R4_Pump_Control.ino` - Arduino Nano R4 firmware.
- `windows-app/Nano_R4_Pump_Control/` - Nano R4 Windows app, launchers, and app README.
- `docs/technical-manual/` - Nano R4 pharmaceutical laboratory style technical manual.

## Default Settings

- Normal run: `32000` steps.
- Purge: `15000` fixed steps.
- Speed: `210 us`.
- USB serial: `115200`.
- Press switch short press: normal run.
- Press switch long press, 3 seconds or more: purge run.

## CL42T Common-Anode Wiring

| CL42T | Arduino Nano R4 |
| --- | --- |
| `PUL+` | regulated `5V` |
| `PUL-` | `A5` |
| `DIR+` | regulated `5V` |
| `DIR-` | `D2` |
| `ENA+` | regulated `5V`, optional |
| `ENA-` | `A1`, optional |
| Press switch | `A2` and `GND` |

Do not use 24V directly with Arduino pins. For direct Arduino-to-CL42T wiring, use regulated 5V on `PUL+`, `DIR+`, and `ENA+`.

## How To Use

1. Open Arduino IDE.
2. Upload `firmware/Nano_R4_Pump_Control/Nano_R4_Pump_Control.ino` to the Arduino Nano R4.
3. Close Arduino IDE Serial Monitor.
4. Connect the Nano R4 by USB.
5. Run `windows-app/Nano_R4_Pump_Control/Run_NanoR4PumpControl_Silent.vbs`.
6. Select the Nano R4 COM port and press `Connect`.
7. Press `Read`, set `Steps` and `Speed us` if needed, then use `RUN`, `PURGE`, or the physical switch.

## Physical Press Switch

- Less than 3 seconds: normal run.
- 3 seconds or more: purge, fixed 15000 steps.
- The action starts when the switch is released.
- Very short pulses are ignored to prevent false starts from switch noise.

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
