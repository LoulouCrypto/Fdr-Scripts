sudo systemctl stop FDReserve*
 echo -e "Stoping Node"
sleep 30
cd
echo -e "Updating Node"
wget http://jackfruit.hopto.org:8888/2021-03-15_FDReserve_V230_Linux64.zip
sleep 1
unzip 2021-03-15_FDReserve_V230_Linux64.zip
sleep 1
rm 2021-03-15_FDReserve_V230_Linux64.zip fdreserve-qt
sleep 1
chmod +x fdreserve*
sleep 1
rm /usr/local/bin/fdreserve*
sleep 1
mv fdreserve* /usr/local/bin/
sleep 2
cd .fdreserve
sleep 2
echo -e "Bootstraping Node"
rm snapshot.zip
sleep 2
wget https://fdreserve.com/downloads/snapshot.zip
rm -r blocks chainstate
unzip snapshot.zip
sleep 2
rm snapshot.zip
sleep 2
cd
rm update-2-2-2-1.sh
echo -e "Starting Node"
sudo systemctl start FDReserve
sleep 30
