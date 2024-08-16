import argparse
import glob
import pprint
import serial

parser = argparse.ArgumentParser()
parser.add_argument("-v", "--verbose", action="store_true")
args = parser.parse_args()

def get_usb_comm_ports():
    ports = glob.glob('/dev/ttyUSB*')
    ports.sort()
    return ports

def get_modem_ports(comm_ports):
    modem_ports = []
    for port in comm_ports:
        try:
            with serial.Serial(port, 9600, timeout=0.1) as test_port:
                command = "ATE0\r\n".encode("utf-8")  # Turn on command echo
                test_port.write(command)
                response = test_port.read(100)
                if b'OK' in response:
                    modem_ports.append(port)
        except Exception as e:
            if args.verbose:
                print(f"error in getting AT status on port: {port}, error: {e}")
            continue
    return modem_ports

def get_modem_information(modem_ports):
    modems_info = []
    for port in modem_ports:
        try:
            with serial.Serial(port, 9600, timeout=0.1) as test_port:
                command = "AT+GSN\r\n".encode('utf-8')  # read serial number
                test_port.write(command)
                response = test_port.read(100)

                start_index = len(b'AT+GSN\r\n\r\n')
                end_index = response.index(b'\r\n\r\nOK\r\n')
                serial_number = response[start_index:end_index].decode()

                command = "AT+GMM\r\n".encode('utf-8')  # get model number
                test_port.write(command)
                response = test_port.read(100)

                start_index = 2
                end_index = response.index(b'\r\n\r\nOK\r\n')
                model_number = response[start_index:end_index].decode()

                command = "AT+CPIN?\r\n".encode('utf-8')  # get SIM card state
                test_port.write(command)
                response = test_port.read(100)
                if b'ERROR' in response:  # no SIM
                    SIM_installed = False
                else:
                    SIM_installed = True

                if not SIM_installed:
                    modems_info.append((port, model_number))

        except Exception as e:
            if args.verbose:
                print(f"error getting modem information for port {port}, error: {e}")

    return modems_info

def print_modem_info(modems_info):
    print("<MODEM_LIST>")
    for port, model_number in modems_info:
        print(f"<COMM_PORT>{port}<END_COMM_PORT>")
        print(f"<MODEL_NUMBER>{model_number}<END_MODEL_NUMBER>")
    print("<END_MODEM_LIST>")

if __name__ == "__main__":
    comm_ports = get_usb_comm_ports()
    if args.verbose:
        print(f"Discovered USB comm ports: {pprint.pformat(comm_ports)}")

    modem_ports = get_modem_ports(comm_ports)
    if args.verbose:
        print(f"Discovered modem comm ports: {pprint.pformat(modem_ports)}")

    modems_info = get_modem_information(modem_ports)
    print_modem_info(modems_info)
