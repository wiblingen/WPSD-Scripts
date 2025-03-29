#!/usr/bin/python3

#
# (C) 2025, by Lucas Burns, AE0LI
#

import serial
import sys
import os

MODEM_BAUDRATE = 115200
MMDVM_SERIAL = 0x80

def MakeNextionCommand(commandString: str):
    result = bytearray()
    result.extend(commandString.encode())
    result.extend([0xff, 0xff, 0xff])
    return result

def MakeSetTextCommandString(item, value):
    commandString = item
    commandString += ".txt=\""
    commandString += value
    commandString += "\""
    return commandString

def MakeModemCommand(nextionCommand: bytearray):
    frameLength = len(nextionCommand) + 3
    result = bytearray()
    result.append(0xe0)
    result.append(frameLength)
    result.append(MMDVM_SERIAL)
    result.extend(nextionCommand)
    return result

def SendModemCommand(mmdvmCommand: bytearray, serialInterface: serial.Serial):
    serialInterface.write(mmdvmCommand)

def SetTextValue(item, value, serialInterface: serial.Serial):
    command = MakeModemCommand(MakeNextionCommand(MakeSetTextCommandString(item, value)))
    SendModemCommand(command, serialInterface)

if __name__ == "__main__":

    programPath = sys.argv[0]
    programName = os.path.basename(programPath)

    if (len(sys.argv) < 3):
        print(f"Usage: {programName} <port> <text value>")
        sys.exit()

    port = sys.argv[1]
    textValue = sys.argv[2]

    try:
        serialInterface = serial.Serial(port = port, baudrate=MODEM_BAUDRATE)
        SetTextValue("t0", textValue, serialInterface=serialInterface)
        serialInterface.close()

    except serial.SerialException as e:
        print(f"Serial port exception: {e}")
        sys.exit()
