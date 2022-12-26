#FIXGPS on existing install
#Will start 2 services that on boot will set gps to wherever it is on TTYUSB.
#will reboot your system

cd ~
GPSpath=$(pwd)

git clone https://github.com/a28-class/class.git

cd $GPSpath/class
sudo chmod +x fixgps.sh
sudo cp fixgps.sh /usr/bin/
cd $GPSpath

#create the service file
sudo touch /etc/systemd/system/fixgps.service
sudo chown $USER:$USER /etc/systemd/system/fixgps.service
#add the required fields to the service file
sudo echo "[Unit]
Description=fixgps

[Service]
Type=forking
ExecStart=/usr/bin/fixgps.sh

[Install]
WantedBy=multi-user.target" > /etc/systemd/system/fixgps.service

#MAKE THE TIMER
#create the service file
sudo touch /etc/systemd/system/fixgps.timer
sudo chown $USER:$USER /etc/systemd/system/fixgps.timer
#add the required fields to the service file

# fixgps.timer
sudo echo "[Unit] 
Description=Runs the fixgps.service 10 seconds after boot up

[Timer] 
OnBootSec=10
Unit=fixgps.service 

[Install] 
WantedBy=basic.target" > /etc/systemd/system/fixgps.timer

#Reload all systemd service files
sudo systemctl daemon-reload

#start the timer service
sudo systemctl enable fixgps.timer
sudo reboot
