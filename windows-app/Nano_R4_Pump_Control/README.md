# V3-0 Nano R4 Peristaltic filling by G.C.

USB/COM pump controller for **Arduino Nano R4** and CL42T driver.

## Files

- `Nano_R4_Pump_Control/Nano_R4_Pump_Control.ino`: main firmware.
- `Nano_R4_CL42T_Common_Anode_Test/Nano_R4_CL42T_Common_Anode_Test.ino`: simple motion test.
- `NanoR4PumpControl.ps1`: Windows PowerShell/WinForms app.
- `Run_NanoR4PumpControl_Silent.vbs`: opens the app without showing PowerShell.

## Arduino IDE

Install the Arduino UNO R4 Boards core, then select:

```text
Board: Arduino Nano R4
Port: COM for Nano R4
Upload: normal Upload button
```

## CL42T Common Anode Wiring

Start with ENA disconnected.

```text
PUL+ -> regulated +5V
DIR+ -> regulated +5V
ENA disconnected

PUL- -> Nano R4 A5
DIR- -> Nano R4 D2

Press switch -> A2 and GND
```

If ENA control is needed later:

```text
ENA+ -> regulated +5V
ENA- -> Nano R4 A1
```

## Power

Use the 24V supply for CL42T motor power. Use a buck converter set to 5.0V for Nano R4 logic/signal power if needed. Do not connect 24V to Nano R4 I/O pins.

## Default Settings

```text
Steps = 32000
Purge = 15000 steps
Speed = 210 us
Baudrate = 115200
```

## Test First

Upload `Nano_R4_CL42T_Common_Anode_Test.ino` first.

If the test does not move:

1. Keep ENA disconnected.
2. Verify `PUL+` and `DIR+` have +5V.
3. Verify `PUL-` is on `A5`.
4. Verify `DIR-` is on `D2`.
5. Verify CL42T motor power, alarm status, and motor wiring.

If the test moves, upload `Nano_R4_Pump_Control.ino` and use the Windows app.

## Operation

- Short press the physical switch to run the saved step count.
- Hold the physical switch for 3 seconds or more to purge 15000 steps.
- Very short switch pulses are ignored to prevent false starts.
- USB RUN and PURGE controls work when the Windows app is connected.
