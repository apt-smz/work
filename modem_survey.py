import argparse
import json
import math
import pprint
import threading
import time
from datetime import datetime
import serial
import plmn_dict
import os

PLMN_DICT = plmn_dict.plmn_dict

desc_message = "Utility for surveying cellular environment."
parser = argparse.ArgumentParser(description=desc_message)
parser.add_argument("--comm_port")
parser.add_argument("--model_number")
parser.add_argument("-sc", "--scancontrol")  # for QOPS scancontrol, 2G, 3G, 4G, all
parser.add_argument("-m", "--mode")  # for QSCAN mode, LTE, 5G, all
parser.add_argument("-b", "--band")  # TODO: implement specific band scan
parser.add_argument("-p", "--parse")  # parse options, JSON or CSV
parser.add_argument("-o", "--output_prefix")  # output file prefix
parser.add_argument("-gl", "--get_location", action="store_true")
parser.add_argument("-v", "--verbose", action="store_true")

args = parser.parse_args()

# Ensure the output directory exists
output_directory = "/home/finch/src/work/cell_survey"
os.makedirs(output_directory, exist_ok=True)

def string_to_int(string_value, base=10):
    if string_value == '-' or string_value == '':
        return None
    else:
        return int(string_value, base)


def format_date(date_str):
    """Format date from DDMMYY to MM/DD/YYYY"""
    try:
        return datetime.strptime(date_str, "%d%m%y").strftime("%m/%d/%Y")
    except ValueError:
        return date_str


class modemSurvey(object):
    def __init__(self, args=None):
        self.args = args
        self.comm_port = serial.Serial(args.comm_port, 9600, timeout=0.1)
        self.collection_thread = None

        self.latitude = None
        self.longitude = None
        self.altitude = None
        self.utc_time = None  # hhmmss.sss
        self.utc_date = None  # ddmmyy

        self.scancontrol_lookup = {"2G": 0,
                                   "3G": 1,
                                   "4G": 2,
                                   "all": 3}

        self.mode_lookup = {"LTE": 1,
                            "5G": 2,
                            "all": 3}

        self.collection_lookup = {"EG25": self.QOPS_collect,
                                  "EM05": self.QOPS_collect,
                                  "RM502Q-AE": self.QSCAN_collect,
                                  "LN920A12-WW": self.CSURVC_collect}

        self.output_files = {
            '2G': None,
            '3G': None,
            '4G': None
        }

        self.start()

    def start(self):
        if self.args.verbose:
            print(f"starting modem survey on port: {self.args.comm_port} for model: {self.args.model_number}")

        self.turn_off_echo()

        if self.args.get_location:
            self.get_location()

        self.collection_thread = threading.Thread(target=self.collection_lookup[self.args.model_number])
        self.collection_thread.start()

    def turn_off_echo(self):
        if self.args.verbose:
            print("turning off echo with ATE0 command")
        try:
            self.comm_port.write("ATE0\r\n".encode("utf-8"))
            response = self.comm_port.read(100).decode()
            if self.args.verbose:
                print(f"ATE0 response: {response}")
        except Exception as e:
            print(f"error trying to turn off echo with ATE0 command, error: {e}")

    def band_lookup(self, earfcn):
        if (earfcn >= 0) and (earfcn < 600):
            return 1
        elif (earfcn >= 600) and (earfcn < 1200):
            return 2
        elif (earfcn >= 1200) and (earfcn < 1950):
            return 3
        elif (earfcn >= 1950) and (earfcn < 2400):
            return 4
        elif (earfcn >= 2400) and (earfcn < 2650):
            return 5
        elif (earfcn >= 2650) and (earfcn < 2750):
            return 6
        elif (earfcn >= 2750) and (earfcn < 3450):
            return 7
        elif (earfcn >= 3450) and (earfcn < 3800):
            return 8
        elif (earfcn >= 3800) and (earfcn < 4150):
            return 9
        elif (earfcn >= 4150) and (earfcn < 4750):
            return 10
        elif (earfcn >= 4750) and (earfcn < 5010):
            return 11
        elif (earfcn >= 5010) and (earfcn < 5180):
            return 12
        elif (earfcn >= 5180) and (earfcn < 5280):
            return 13
        elif (earfcn >= 5280) and (earfcn < 5380):
            return 14
        elif (earfcn >= 5730) and (earfcn < 5850):
            return 17
        elif (earfcn >= 5850) and (earfcn < 6000):
            return 18
        elif (earfcn >= 6000) and (earfcn < 6150):
            return 19
        elif (earfcn >= 6150) and (earfcn < 6450):
            return 20
        elif (earfcn >= 6450) and (earfcn < 6600):
            return 21
        elif (earfcn >= 6600) and (earfcn < 7400):
            return 22
        elif (earfcn >= 7500) and (earfcn < 7700):
            return 23
        elif (earfcn >= 7700) and (earfcn < 8040):
            return 24
        elif (earfcn >= 8040) and (earfcn < 8690):
            return 25
        elif (earfcn >= 8690) and (earfcn < 9040):
            return 26
        elif (earfcn >= 9040) and (earfcn < 9210):
            return 27
        elif (earfcn >= 9210) and (earfcn < 9660):
            return 28
        elif (earfcn >= 9660) and (earfcn < 9770):
            return 29
        elif (earfcn >= 9770) and (earfcn < 9870):
            return 30
        elif (earfcn >= 9870) and (earfcn < 9920):
            return 31
        elif (earfcn >= 9920) and (earfcn < 10360):
            return 32
        elif (earfcn >= 36000) and (earfcn < 36200):
            return 33
        elif (earfcn >= 36200) and (earfcn < 36350):
            return 34
        elif (earfcn >= 36350) and (earfcn < 36950):
            return 35
        elif (earfcn >= 36950) and (earfcn < 37550):
            return 36
        elif (earfcn >= 37550) and (earfcn < 37750):
            return 37
        elif (earfcn >= 37750) and (earfcn < 38250):
            return 38
        elif (earfcn >= 38250) and (earfcn < 38650):
            return 39
        elif (earfcn >= 38650) and (earfcn < 39650):
            return 40
        elif (earfcn >= 39650) and (earfcn < 41590):
            return 41
        elif (earfcn >= 41590) and (earfcn < 43590):
            return 42
        elif (earfcn >= 43590) and (earfcn < 45590):
            return 43
        elif (earfcn >= 45590) and (earfcn < 46590):
            return 44
        else:
            return None

    def get_location(self):
        if self.args.verbose:
            print("getting location")

        # turn on gps
        command = 'AT+QGPS=1\r\n'.encode('utf-8')
        try:
            self.comm_port.write(command)
            response = self.comm_port.read(100).decode()
            if self.args.verbose:
                print("turning on gps")
                print(f'AT+QGPS=1, response: {response}')
        except Exception as e:
            print(f'error trying to set AT+QGPS=1, error: {e}')

        time.sleep(1)

        # get location
        command = 'AT+QGPSLOC=2\r\n'.encode('utf-8')
        try:
            self.comm_port.write(command)
            response = self.comm_port.read(100).decode()
            if self.args.verbose:
                print("getting gps location")
                print(f'AT+QGPSLOC=2, response: {response}')
            if "ERROR" in response:
                print(f"location_result, ERROR: {response}")
                response = None
        except Exception as e:
            response = None
            print(f'error trying to get AT+QGPSLOC=2, error: {e}')

        if response:
            QGPSLOC_split = response.split("+QGPSLOC: ")
            location_split = QGPSLOC_split[1].strip("\r\nOK\r\n").split(",")
            utc_time, latitude, longitude, hdop, altitude, fix, cog, spkm, spkn, utc_date, nsat = location_split
            self.utc_time = utc_time
            self.utc_date = format_date(utc_date)
            self.latitude = latitude
            self.longitude = longitude
            self.altitude = altitude
            if self.args.verbose:
                print(f"location_result, utc_time={utc_time}, latitude={latitude}, longitude={longitude}, hdop={hdop}, altitude={altitude}, fix={fix}, cog={cog}, spkm={spkm}, spkn={spkn}, utc_date={self.utc_date}, number_of_sats={nsat}")

    def QOPS_collect(self):
        if self.args.verbose:
            print("starting QOPS collect")

        if self.args.scancontrol:
            scancontrol = self.scancontrol_lookup[self.args.scancontrol]
        else:
            scancontrol = 3  # default to 2/3/4G

        command = f'AT+QOPSCFG="scancontrol",{scancontrol}\r\n'.encode("utf-8")  # scancontrol must in double quotes " ", 0=2G, 1=3G, 2=4G, 3=2/3/4G
        try:
            self.comm_port.write(command)
            response = self.comm_port.read(100).decode()
            if self.args.verbose:
                print("setting scancontrol")
                print(f'AT+QOPSCFG="scancontrol", {scancontrol}; response: {response}')
        except Exception as e:
            print(f'error trying to set AT+QOPSCFG="scancontrol", {scancontrol}; error: {e}')

        command = 'AT+QOPSCFG="displayrssi",1\r\n'.encode("utf-8")  # displayrssi must be in double quotes " "
        try:
            self.comm_port.write(command)
            response = self.comm_port.read(100).decode()
            if self.args.verbose:
                print("setting displayrssi")
                print(f'AT+QOPSCFG="displayrssi", 1; response: {response}')
        except Exception as e:
            print(f'error trying to set AT+QOPSCFG="displayrssi", 1; error: {e}')

        time.sleep(1)

        try:
            self.comm_port.write("AT+QOPS\r\n".encode("utf-8"))
            count = 0
            while(not self.comm_port.in_waiting):
                time.sleep(1)
                count += 1
                if self.args.verbose:
                    print(f'waiting {count} secs')
            if self.args.verbose:
                print(f'waited {count} secs for response')

            self.comm_port.timeout = 5
            response = self.comm_port.read_until('OK').decode()
            if self.args.verbose:
                print(f"AT+QOPS response: {response}")
        except Exception as e:
            response = None
            print(f"error trying to run AT+QOPS; error: {e}")

        if response:
            if self.args.parse == "JSON":
                self.QOPS_JSON_parse(response)
            elif self.args.parse == "CSV":
                self.QOPS_CSV_parse(response)
            elif self.args.parse == "KEYVAL":
                self.QOPS_KEYVAL_parse(response)
            else:
                self.QOPS_JSON_parse(response)

    def QOPS_JSON_parse(self, collection):
        if self.args.verbose:
            print("JSON parsing QOPS response")
        band_scan = {
            '2G': [],
            '3G': [],
            '4G': []
        }

        operator_split = collection.split('+QOPS: ')

        for operator in operator_split[1:]:
            band_entry = {}

            lines = operator.split('\r\n')

            operator_string, operator_short_string, operator_number, = lines[0].replace('"','').split(',')
            band_entry['oper_in_string'] = operator_string  # operator name in long string
            band_entry['oper_in_short_string'] = operator_short_string  # operator name in short string
            band_entry['PLMN'] = operator_number  # changed to PLMN
            mcc = operator_number[:3]
            mnc = operator_number[3:]
            band_entry['mcc'] = mcc  # mobile country code, first part of PLMN code
            band_entry['mnc'] = mnc  # mobile network code, second part of PLMN code
            band_entry['country'] = PLMN_DICT[mcc][mnc]['country']
            band_entry['provider'] = PLMN_DICT[mcc][mnc]['operator']
            for line in lines[1:]:
                split_line = line.replace('"', '').split(',')
                if len(split_line) >= 9:
                    index_entry = {}
                    if split_line[1] == '2G':
                        index, rat, freq, lac, ci, bsci, rxlev, c1, cba, is_gprs_support, = split_line

                        index_entry["RAT"] = rat  # 2G, 3G, or 4G
                        index_entry["arfcn"] = int(freq)  # ARFCN/UARFCN/EARFCN of cell
                        index_entry["lac"] = int(lac, 16)  # location area code
                        index_entry["ci"] = int(ci, 16)  # cell id, globally unique, like a MAC address should be static
                        index_entry["bsci"] = int(bsci)  # base station identification code
                        index_entry["rssi"] = 111 - int(rxlev)  # RX level adjusted and renamed to RSSI
                        index_entry["c1"] = int(c1)  # cell selection criterion
                        index_entry["cba"] = int(cba)  # cell bar access 0=unbarred cell, 1=barred cell
                        index_entry["is_gprs_support"] = int(is_gprs_support)  # GPRS support or not, 0=No support, 1=Support GPRS
                        band_scan['2G'].append(index_entry)
                    elif split_line[1] == '3G':
                        index, rat, freq, psc, lac, ci, rscp, ecno, cba, = split_line

                        index_entry["RAT"] = rat  # 2G, 3G, or 4G
                        index_entry["uarfcn"] = int(freq)  # ARFCN/UARFCN/EARFCN of cell
                        index_entry["psc"] = int(psc)  # primary scrambling code
                        index_entry["lac"] = int(lac, 16)  # location area code
                        index_entry["ci"] = int(ci, 16)  # cell id, globally unique, like a MAC address should be static
                        index_entry["rscp"] = int(rscp)  # received signal code power level
                        index_entry["ecno"] = int(ecno)  # indicator of network quality
                        index_entry["cba"] = int(cba)  # cell bar access 0=unbarred cell, 1=barred cell
                        band_scan['3G'].append(index_entry)
                    elif split_line[1] == '4G':
                        index, rat, freq, pci, tac, ci, rsrp, rsrq, rssi, cba, = split_line

                        index_entry["RAT"] = rat  # 2G, 3G, or 4G
                        index_entry["earfcn"] = int(freq)  # ARFCN/UARFCN/EARFCN of cell
                        index_entry["band"] = self.band_lookup(int(freq))
                        index_entry["pci"] = int(pci)  # physical cell id, cell level synchronization can change frequently
                        index_entry["tac"] = int(tac, 16)  # tracking area code
                        index_entry["ci"] = int(ci, 16)  # cell id, globally unique, like a MAC address should be static
                        index_entry["rsrp"] = int(rsrp)  # reference signal receiving power
                        index_entry["rsrq"] = int(rsrq)  # reference signal receiving quality
                        index_entry["rssi"] = int(rssi)  # received signal strength indicator
                        index_entry["cba"] = int(cba)  # cell bar access 0=unbarred cell, 1=barred cell
                        band_scan['4G'].append(index_entry)

        for rat, data in band_scan.items():
            if data:
                file_name = os.path.join(output_directory, f"{self.args.output_prefix}_{rat}.json" if self.args.parse == "JSON" else f"{self.args.output_prefix}_{rat}.csv")
                self.output_files[rat] = open(file_name, 'w')
                if self.args.parse == "JSON":
                    json.dump(data, self.output_files[rat], indent=4)
                else:
                    self.write_csv(data, rat)

    def write_csv(self, data, rat):
        if rat == '2G':
            heading = "operator_string, operator_short_string, PLMN, mobile_country_code, mobile_network_code, country, provider, index, radio_access_technology, arfcn, location_area_code, cell_id, base_station_identification_code, rssi, cell_selection_criteria, cell_bar_access, is_gprs_support, utc_time, utc_date, latitude, longitude, altitude"
        elif rat == '3G':
            heading = "operator_string, operator_short_string, PLMN, mobile_country_code, mobile_network_code, country, provider, index, radio_access_technology, urfcn, primary_scrambling_code, location_area_code, cell_id, received_signal_code_power_level, ecno, cell_bar_access, utc_time, utc_date, latitude, longitude, altitude"
        elif rat == '4G':
            heading = "operator_string, operator_short_string, PLMN, mobile_country_code, mobile_network_code, country, provider, index, radio_access_technology, earfcn, band, physical_cell_id, tracking_area_code, cell_id, reference_signal_receiving_power, reference_signal_receiving_quality, received_signal_strength_indicator, cell_bar_access, utc_time, utc_date, latitude, longitude, altitude"
        else:
            return

        with self.output_files[rat] as f:
            f.write(heading + '\n')
            for entry in data:
                values = [str(entry.get(col, '')) for col in heading.split(', ')]
                f.write(', '.join(values) + '\n')

    def QOPS_CSV_parse(self, collection):
        if self.args.verbose:
            print("CSV parsing QOPS response")
        band_scan = {
            '2G': [],
            '3G': [],
            '4G': []
        }

        QOPS_split = collection.split("+QOPS: ")

        for operator in QOPS_split[1:]:
            lines = operator.split('\r\n')
            operator_string, operator_short_string, operator_number = lines[0].replace('"','').split(',')

            mobile_country_code = operator_number[:3]  # mcc
            mobile_network_code = operator_number[3:]  # mnc
            country = PLMN_DICT[mobile_country_code][mobile_network_code]['country']
            provider = PLMN_DICT[mobile_country_code][mobile_network_code]['operator']

            for line in lines:
                split_line = line.replace('"', '').split(',')
                if len(split_line) >= 9:
                    index_entry = {}
                    if split_line[1] == '2G':
                        index, rat, freq, lac, ci, bsci, rxlev, c1, cba, is_gprs_support, = split_line
                        index_entry = {
                            "operator_string": operator_string,
                            "operator_short_string": operator_short_string,
                            "PLMN": operator_number,  # changed to PLMN
                            "mobile_country_code": mobile_country_code,
                            "mobile_network_code": mobile_network_code,
                            "country": country,
                            "provider": provider,
                            "index": index,
                            "radio_access_technology": rat,
                            "arfcn": int(freq),
                            "location_area_code": int(lac, 16),
                            "cell_id": int(ci, 16),
                            "base_station_identification_code": int(bsci),
                            "rssi": 111 - int(rxlev),  # Adjusting rx_level and renaming to rssi
                            "cell_selection_criteria": int(c1),
                            "cell_bar_access": int(cba),
                            "is_gprs_support": int(is_gprs_support),
                            "utc_time": self.utc_time,
                            "utc_date": self.utc_date,
                            "latitude": self.latitude,
                            "longitude": self.longitude,
                            "altitude": self.altitude
                        }
                        band_scan['2G'].append(index_entry)
                    elif split_line[1] == '3G':
                        index, rat, freq, psc, lac, ci, rscp, ecno, cba, = split_line
                        index_entry = {
                            "operator_string": operator_string,
                            "operator_short_string": operator_short_string,
                            "PLMN": operator_number,  # changed to PLMN
                            "mobile_country_code": mobile_country_code,
                            "mobile_network_code": mobile_network_code,
                            "country": country,
                            "provider": provider,
                            "index": index,
                            "radio_access_technology": rat,
                            "uarfcn": int(freq),
                            "primary_scrambling_code": int(psc),
                            "location_area_code": int(lac, 16),
                            "cell_id": int(ci, 16),
                            "received_signal_code_power_level": int(rscp),
                            "ecno": int(ecno),
                            "cell_bar_access": int(cba),
                            "utc_time": self.utc_time,
                            "utc_date": self.utc_date,
                            "latitude": self.latitude,
                            "longitude": self.longitude,
                            "altitude": self.altitude
                        }
                        band_scan['3G'].append(index_entry)
                    elif split_line[1] == '4G':
                        index, rat, freq, pci, tac, ci, rsrp, rsrq, rssi, cba, = split_line
                        index_entry = {
                            "operator_string": operator_string,
                            "operator_short_string": operator_short_string,
                            "PLMN": operator_number,  # changed to PLMN
                            "mobile_country_code": mobile_country_code,
                            "mobile_network_code": mobile_network_code,
                            "country": country,
                            "provider": provider,
                            "index": index,
                            "radio_access_technology": rat,
                            "earfcn": int(freq),
                            "band": self.band_lookup(int(freq)),
                            "physical_cell_id": int(pci),
                            "tracking_area_code": int(tac, 16),
                            "cell_id": int(ci, 16),
                            "reference_signal_receiving_power": int(rsrp),
                            "reference_signal_receiving_quality": int(rsrq),
                            "received_signal_strength_indicator": int(rssi),
                            "cell_bar_access": int(cba),
                            "utc_time": self.utc_time,
                            "utc_date": self.utc_date,
                            "latitude": self.latitude,
                            "longitude": self.longitude,
                            "altitude": self.altitude
                        }
                        band_scan['4G'].append(index_entry)

        for rat, data in band_scan.items():
            if data:
                file_name = os.path.join(output_directory, f"{self.args.output_prefix}_{rat}.csv")
                self.output_files[rat] = open(file_name, 'w')
                self.write_csv(data, rat)

    def QOPS_KEYVAL_parse(self, collection):
        if self.args.verbose:
            print("KEYVAL parsing QOPS response")
        band_scan = {
            '2G': [],
            '3G': [],
            '4G': []
        }

        QOPS_split = collection.split("+QOPS: ")

        for operator in QOPS_split[1:]:
            lines = operator.split('\r\n')
            operator_string, operator_short_string, operator_number = lines[0].replace('"','').split(',')

            mobile_country_code = operator_number[:3]  # mcc
            mobile_network_code = operator_number[3:]  # mnc
            country = PLMN_DICT[mobile_country_code][mobile_network_code]['country']
            provider = PLMN_DICT[mobile_country_code][mobile_network_code]['operator']

            for line in lines:
                split_line = line.replace('"', '').split(',')
                if len(split_line) >= 9:
                    index_entry = {}
                    if split_line[1] == '2G':
                        index, rat, freq, lac, ci, bsci, rxlev, c1, cba, is_gprs_support, = split_line
                        index_entry = {
                            "operator_string": operator_string,
                            "operator_short_string": operator_short_string,
                            "PLMN": operator_number,  # changed to PLMN
                            "mobile_country_code": mobile_country_code,
                            "mobile_network_code": mobile_network_code,
                            "country": country,
                            "provider": provider,
                            "index": index,
                            "radio_access_technology": rat,
                            "arfcn": int(freq),
                            "location_area_code": int(lac, 16),
                            "cell_id": int(ci, 16),
                            "base_station_identification_code": int(bsci),
                            "rssi": 111 - int(rxlev),  # Adjusting rx_level and renaming to rssi
                            "cell_selection_criteria": int(c1),
                            "cell_bar_access": int(cba),
                            "is_gprs_support": int(is_gprs_support),
                            "utc_time": self.utc_time,
                            "utc_date": self.utc_date,
                            "latitude": self.latitude,
                            "longitude": self.longitude,
                            "altitude": self.altitude
                        }
                        band_scan['2G'].append(index_entry)
                    elif split_line[1] == '3G':
                        index, rat, freq, psc, lac, ci, rscp, ecno, cba, = split_line
                        index_entry = {
                            "operator_string": operator_string,
                            "operator_short_string": operator_short_string,
                            "PLMN": operator_number,  # changed to PLMN
                            "mobile_country_code": mobile_country_code,
                            "mobile_network_code": mobile_network_code,
                            "country": country,
                            "provider": provider,
                            "index": index,
                            "radio_access_technology": rat,
                            "uarfcn": int(freq),
                            "primary_scrambling_code": int(psc),
                            "location_area_code": int(lac, 16),
                            "cell_id": int(ci, 16),
                            "received_signal_code_power_level": int(rscp),
                            "ecno": int(ecno),
                            "cell_bar_access": int(cba),
                            "utc_time": self.utc_time,
                            "utc_date": self.utc_date,
                            "latitude": self.latitude,
                            "longitude": self.longitude,
                            "altitude": self.altitude
                        }
                        band_scan['3G'].append(index_entry)
                    elif split_line[1] == '4G':
                        index, rat, freq, pci, tac, ci, rsrp, rsrq, rssi, cba, = split_line
                        index_entry = {
                            "operator_string": operator_string,
                            "operator_short_string": operator_short_string,
                            "PLMN": operator_number,  # changed to PLMN
                            "mobile_country_code": mobile_country_code,
                            "mobile_network_code": mobile_network_code,
                            "country": country,
                            "provider": provider,
                            "index": index,
                            "radio_access_technology": rat,
                            "earfcn": int(freq),
                            "band": self.band_lookup(int(freq)),
                            "physical_cell_id": int(pci),
                            "tracking_area_code": int(tac, 16),
                            "cell_id": int(ci, 16),
                            "reference_signal_receiving_power": int(rsrp),
                            "reference_signal_receiving_quality": int(rsrq),
                            "received_signal_strength_indicator": int(rssi),
                            "cell_bar_access": int(cba),
                            "utc_time": self.utc_time,
                            "utc_date": self.utc_date,
                            "latitude": self.latitude,
                            "longitude": self.longitude,
                            "altitude": self.altitude
                        }
                        band_scan['4G'].append(index_entry)

        for rat, data in band_scan.items():
            if data:
                file_name = os.path.join(output_directory, f"{self.args.output_prefix}_{rat}.txt")
                self.output_files[rat] = open(file_name, 'w')
                for entry in data:
                    line_1 = f"operator_string={entry['operator_string']}, operator_short_string={entry['operator_short_string']}, PLMN={entry['PLMN']}, mobile_country_code={entry['mobile_country_code']}, mobile_network_code={entry['mobile_network_code']}, country={entry['country']},"
                    line_2 = f"provider={entry['provider']}, index={entry['index']}, radio_access_technology={entry['radio_access_technology']},"
                    if rat == '2G':
                        line_3 = f"arfcn={entry['arfcn']}, location_area_code={entry['location_area_code']}, cell_id={entry['cell_id']}, base_station_identification_code={entry['base_station_identification_code']}, rssi={entry['rssi']}, cell_selection_criteria={entry['cell_selection_criteria']}, cell_bar_access={entry['cell_bar_access']}, is_gprs_support={entry['is_gprs_support']}"
                    elif rat == '3G':
                        line_3 = f"uarfcn={entry['uarfcn']}, primary_scrambling_code={entry['primary_scrambling_code']}, location_area_code={entry['location_area_code']}, cell_id={entry['cell_id']}, received_signal_code_power_level={entry['received_signal_code_power_level']}, ecno={entry['ecno']}, cell_bar_access={entry['cell_bar_access']}"
                    elif rat == '4G':
                        line_3 = f"earfcn={entry['earfcn']}, band={entry['band']}, physical_cell_id={entry['physical_cell_id']}, tracking_area_code={entry['tracking_area_code']}, cell_id={entry['cell_id']}, reference_signal_receiving_power={entry['reference_signal_receiving_power']}, reference_signal_receiving_quality={entry['reference_signal_receiving_quality']}, received_signal_strength_indicator={entry['received_signal_strength_indicator']}, cell_bar_access={entry['cell_bar_access']}"
                    else:
                        line_3 = ""

                    self.output_files[rat].write(f"survey_result, {line_1} {line_2} {line_3}\n")

    def QSCAN_collect(self, ext=1):
        if self.args.verbose:
            print("starting QSCAN collect")
        if self.args.mode:
            mode = self.mode_lookup[self.args.mode]
        else:
            mode = 3
        command = f"AT+QSCAN={mode},{ext}\r\n".encode('utf-8')  # mode 1=LTE, 2=5G, 3=LTE/5G; ext 0=hide extension parameters, 1=show extension parameters

        try:
            self.comm_port.write(command)

            count = 0
            while(not self.comm_port.in_waiting):
                time.sleep(1)
                count += 1
                if self.args.verbose:
                    print(f'waiting {count} secs')
            if self.args.verbose:
                print(f'waited {count} secs for response')

            self.comm_port.timeout = 5
            response = self.comm_port.read_until('OK').decode()
            if self.args.verbose:
                print(f"AT+QSCAN response: {response}")
            self.comm_port.timeout = 0.1
        except Exception as e:
            response = None
            print(f"error trying to run AT+QSCAN; error: {e}")

        if response:
            if self.args.parse == "JSON":
                self.QSCAN_JSON_parse(response)
            elif self.args.parse == "CSV":
                self.QSCAN_CSV_parse(response)
            else:
                self.QSCAN_JSON_parse(response)

    def QSCAN_JSON_parse(self, collection):
        if self.args.verbose:
            print("JSON parsing QSCAN response")
        band_scan = []
        band_entry = {}

        collection = collection.replace('+QSCAN: ', '')
        lines = collection.split('\r\n')

        for line in lines:
            paramter_list = line.replace('"','').split(',')
            if "LTE" in paramter_list:
                if len(paramter_list) >= 9:
                    cell_type, mcc, mnc, freq, pci, rsrp, rsrq, srxlev, squal = paramter_list[:9]
                    band_entry['cell_type'] = cell_type
                    band_entry['mcc'] = mcc
                    band_entry['mnc'] = mnc
                    band_entry['country'] = PLMN_DICT[mcc][mnc]['country']
                    band_entry['provider'] = PLMN_DICT[mcc][mnc]['operator']
                    band_entry['plmn'] = mcc + mnc
                    band_entry['earfcn'] = string_to_int(freq)
                    band_entry['pci'] = string_to_int(pci)
                    band_entry['rsrp'] = string_to_int(rsrp)
                    band_entry['rsrq'] = string_to_int(rsrq)
                    band_entry['srxlev'] = string_to_int(srxlev)
                    band_entry['squal'] = string_to_int(squal)
                    if len(paramter_list) >= 13:
                        cellID, tac, bandwidth, lte_band = paramter_list[9:13]
                        band_entry['cellID'] = string_to_int(cellID, 16)
                        band_entry['tac'] = string_to_int(tac, 16)
                        band_entry['bandwidth'] = string_to_int(bandwidth)
                        band_entry['lte_band'] = string_to_int(lte_band)

                        if (band_entry['bandwidth']):
                            rssi = band_entry['rsrp'] + 10 * math.log10(12 * band_entry['bandwidth'])
                            band_entry['rssi'] = string_to_int(rssi)

                        if len(paramter_list) > 13:
                            short_name, full_name = paramter_list[13:15]
                            band_entry['short_name'] = short_name
                            band_entry['full_name'] = full_name

                band_scan.append(band_entry)

            elif "NR5G" in paramter_list:
                if len(paramter_list) >= 9:
                    cell_type, mcc, mnc, freq, pci, rsrp, rsrq, srxlev, scs = paramter_list[:9]
                    band_entry['cell_type'] = cell_type
                    band_entry['mcc'] = string_to_int(mcc)
                    band_entry['mnc'] = string_to_int(mnc)
                    band_entry['freq'] = string_to_int(freq)
                    band_entry['pci'] = string_to_int(pci)
                    band_entry['rsrp'] = string_to_int(rsrp)
                    band_entry['rsrq'] = string_to_int(rsrq)
                    band_entry['srxlev'] = string_to_int(srxlev)
                    band_entry['scs'] = string_to_int(scs)
                    if len(paramter_list) >= 16:
                        cellID, tac, carrier_bandwidth, band, offset_to_point_A, SSB_subcarrier_offset, SSB_SCS = paramter_list[9:16]
                        band_entry['cellID'] = string_to_int(cellID, 16)
                        band_entry['tac'] = string_to_int(tac, 16)
                        band_entry['carrier_bandwidth'] = string_to_int(carrier_bandwidth)
                        band_entry['band'] = string_to_int(band)
                        band_entry['offset_to_point_A'] = string_to_int(offset_to_point_A)
                        band_entry['SSB_subcarrier_offset'] = string_to_int(SSB_subcarrier_offset)
                        band_entry['SSB_SCS'] = string_to_int(SSB_SCS)
                        if len(paramter_list) > 16:
                            short_name, full_name = paramter_list[16:18]
                            band_entry['short_name'] = short_name
                            band_entry['full_name'] = full_name

                band_scan.append(band_entry)

            band_entry = {}

        if band_scan:
            file_name = os.path.join(output_directory, f"{self.args.output_prefix}_4G.json")
            self.output_files['4G'] = open(file_name, 'w')
            json.dump(band_scan, self.output_files['4G'], indent=4)
        else:
            pprint.pprint(band_scan)

    def QSCAN_CSV_parse(self, collection):
        if self.args.verbose:
            print("CSV parsing QSCAN response")

    def CSURV_collect(self):
        if self.args.verbose:
            print("starting CSURV collect")

    def CSURVC_collect(self):
        if self.args.verbose:
            print("starting CSURVC collect")

if __name__ == "__main__":
    survey = modemSurvey(args)
