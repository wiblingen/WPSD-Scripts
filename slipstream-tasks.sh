#!/bin/bash

## This script is for near-real-time and periodic fixes, etc.

# Make sure we are root
if [ "$(id -u)" != "0" ]; then
  echo -e "You need to be root to run this command...\n"
  exit 1
fi

# common vars
osName=$( /usr/bin/lsb_release -cs )
CALL=$( grep "Callsign" /etc/pistar-release | awk '{print $3}' )
UUID=$( grep "UUID" /etc/pistar-release | awk '{print $3}' )
OS_VER=$( cat /etc/debian_version | sed 's/\..*//')
gitBranch=$(git --work-tree=/var/www/dashboard --git-dir=/var/www/dashboard/.git symbolic-ref --short HEAD)
dashVer=$( git --work-tree=/var/www/dashboard --git-dir=/var/www/dashboard/.git rev-parse --short=10 ${gitBranch} )
uuidStr=$(egrep 'UUID|ModemType|ModemMode|ControllerType' /etc/pistar-release | awk {'print $3'} | tac | xargs| sed 's/ /_/g')
hwDeetz="$(/usr/local/sbin/platformDetect.sh) ( $(uname -r) )"
uaStr="Ver.# ${dashVer} (${gitBranch}) Call:${CALL} UUID:${uuidStr} [${hwDeetz}] [${osName}]"
armbian_env_file="/boot/armbianEnv.txt"
rc_local_file="/etc/rc.local"

# This part fully-disables read-only mode
#
# 1/2023 - W0CHP (updated on 2/23/2023)
#
if grep -qo ',ro' /etc/fstab ; then
    sed -i 's/defaults,ro/defaults,rw/g' /etc/fstab
    sed -i 's/defaults,noatime,ro/defaults,noatime,rw/g' /etc/fstab
fi
if grep -qo 'remount,ro' /etc/bash.bash_logout ; then
    sed -i '/remount,ro/d' /etc/bash.bash_logout
fi
if grep -qo 'fs_mode:+' /etc/bash.bashrc ; then
    sed -i 's/${fs_mode:+($fs_mode)}//g' /etc/bash.bashrc
fi
if grep -qo 'remount,ro' /usr/local/sbin/pistar-hourly.cron ; then
    sed -i '/# Mount the disk RO/d' /usr/local/sbin/pistar-hourly.cron
    sed -i '/mount -o remount,ro/d' /usr/local/sbin/pistar-hourly.cron
fi
if grep -qo 'remount,ro' $rc_local_file ; then
    sed -i '/remount,ro/d' $rc_local_file
fi
if grep -qo 'remount,ro' /etc/apt/apt.conf.d/100update ; then
    sed -i '/remount,ro/d' /etc/apt/apt.conf.d/100update
fi
if grep -qo 'remount,ro' /lib/systemd/system/apt-daily-upgrade.service ; then
    sed -i '/remount,ro/d' /lib/systemd/system/apt-daily-upgrade.service
    systemctl daemon-reload 
fi
if grep -qo 'remount,ro' /lib/systemd/system/apt-daily.service ; then
    sed -i '/remount,ro/d' /lib/systemd/system/apt-daily.service
    systemctl daemon-reload 
fi
if grep -qo 'remount,ro' /etc/systemd/system/apt-daily-upgrade.service ; then
    sed -i '/remount,ro/d' /etc/systemd/system/apt-daily-upgrade.service
    systemctl daemon-reload 
fi
if grep -qo 'remount,ro' /etc/systemd/system/apt-daily.service ; then
    sed -i '/remount,ro/d' /etc/systemd/system/apt-daily.service
    systemctl daemon-reload 
fi
if grep -qo 'fs_mode=' /etc/bash.bashrc ; then
    sed -i '/fs_mode=/d' /etc/bash.bashrc
fi
if grep -qo '# Aliases to control re-mounting' /etc/bash.bashrc ; then
    sed -i '/# Aliases to control re-mounting/d' /etc/bash.bashrc
fi
if grep -qo 'alias rpi-ro=' /etc/bash.bashrc ; then
    sed -i '/alias rpi-ro=/d' /etc/bash.bashrc
fi
if grep -qo 'alias rpi-rw=' /etc/bash.bashrc ; then
    sed -i '/alias rpi-rw=/d' /etc/bash.bashrc
fi
#

# Tweak shelliniabox/web ssh colors:
#
# 10/2023 - W0CHP
if ! grep -q "Terminal.css" "/etc/default/shellinabox"; then
    sed -i 's/SHELLINABOX_ARGS=.*$/SHELLINABOX_ARGS="--no-beep --disable-ssl-menu --disable-ssl --css=\/etc\/shellinabox\/options-enabled\/00_White\\ On\\ Black.css --css=\/etc\/shellinabox\/options-enabled\/01+Color\\ Terminal.css"/' /etc/default/shellinabox
    systemctl restart shellinabox.service
fi
# 

# Fix legacy radio type misspelling
#
# 6/2023 - W0CHP
if [ -f "/etc/dstar-radio.mmdvmhost" ]; then
    if grep -q "genesysdualhat" "/etc/dstar-radio.mmdvmhost"; then
        sed -i 's/genesysdualhat/genesisdualhat/g' "/etc/dstar-radio.mmdvmhost"
    else
	:
    fi
else
    :
fi
#

# migrate AX.25 entries
#
# 6/2023 W0CHP
if grep -q "AX 25" /etc/mmdvmhost; then
  sed -i 's/AX 25/AX.25/g' /etc/mmdvmhost
fi
#

# migrate legacy network info URLs
# 
# 10/23 W0CHP
files=(
  /etc/dmrgateway
  /etc/ysfgateway
  /etc/p25gateway
  /etc/nxdngateway
  /etc/ircddbgateway
  /etc/m17gateway
  /etc/mmdvmhost
  /etc/nxdn2dmr
  /etc/ysf2dmr
  /etc/ysf2nxdn
  /etc/ysf2p25
  /etc/WPSD_config_mgr/*/*
)
old_url="http://www.mw0mwz.co.uk/pi-star/"
new_url="https://wpsd.radio"
for file in "${files[@]}"; do
  if [[ -f "$file" ]]; then
    if grep -qi "$old_url" "$file"; then
      file_content=$(<"$file")
      if [[ $file_content == *'URL='* ]]; then
        file_content="${file_content//URL=/URL=}"
        file_content="${file_content//$old_url/$new_url}"
        echo -n "$file_content" > "$file"
      elif [[ $file_content == *'url='* ]]; then # ircddbgw etc. uses lowercase keys
        file_content="${file_content//url=/url=}"
        file_content="${file_content//$old_url/$new_url}"
        echo -n "$file_content" > "$file"
      fi
    fi
  fi
done
for file in "${files[@]}"; do
  if [[ -f "$file" ]]; then
    sed -i 's/_W0CHP-PiStar-Dash/_WPSD/g' "$file"
  fi
done
#

# fix YSF2DMR config file w/bad call preventing startup
#
# 7/2023
if grep -q "M1ABC" /etc/ysf2dmr && [ "$CALL" != "M1ABC" ]; then
  sed -i "s/M1ABC/${CALL}/g" /etc/ysf2dmr
fi
#

# Git URI changed when transferring repos from me to the org.
#
# 2/2023 - W0CHP
#
function gitURIupdate () {
    dir="$1"
    gitRemoteURI=$(git --work-tree=${dir} --git-dir=${dir}/.git config --get remote.origin.url)

    git --work-tree=${dir} --git-dir=${dir}/.git config --get remote.origin.url | grep 'WPSD-Dev' &> /dev/null
    if [ $? == 0 ]; then
        newURI=$( echo $gitRemoteURI | sed 's|repo\.w0chp\.net/WPSD-Dev|wpsd-swd.w0chp.net/WPSD-SWD|g' )
        git --work-tree=${dir} --git-dir=${dir}/.git remote set-url origin $newURI
    fi
}
gitURIupdate "/var/www/dashboard"
gitURIupdate "/usr/local/bin"
gitURIupdate "/usr/local/sbin"
#

# Config backup file name change, so lets address that
#
# 5/2023 W0CHP
#
if grep -q 'Pi-Star_Config_\*\.zip' $rc_local_file ; then
    sed -i 's/Pi-Star_Config_\*\.zip/WPSD_Config_\*\.zip/g' $rc_local_file
fi
#

# migrated from other scripts to centralize
#
# 5/2023 W0CHP
#
# cleanup legacy naming convention
if grep -q 'modemcache' $rc_local_file ; then
    sed -i 's/modemcache/hwcache/g' $rc_local_file
    sed -i 's/# cache modem info/# cache hw info/g' $rc_local_file 
fi
# bullseye; change weird interface names* back to what most are accustomed to;
# <https://wiki.debian.org/NetworkInterfaceNames#THE_.22PREDICTABLE_NAMES.22_SCHEME>
# sunxi systems don't have /boot/cmdline.txt so we can ignore that.
# Raspbian::
if [ "${OS_VER}" -gt "10" ] && [ -f '/boot/cmdline.txt' ] && [[ ! $(grep "net.ifnames" /boot/cmdline.txt) ]] ; then
    sed -i 's/$/ net.ifnames=1 biosdevname=0/' /boot/cmdline.txt
fi
# Armbian:
if [ "${OS_VER}" -gt "10" ] && [ -f '/boot/armbianEnv.txt' ] && [[ ! $(grep "net.ifnames" /boot/armbianEnv.txt) ]] ; then
    sed -i '$ a\extraargs=net.ifnames=0' /boot/armbianEnv.txt
fi
# ensure pistar-remote config has key-value pairs for new funcs (12/2/22)
if ! grep -q 'hostfiles=8999995' /etc/pistar-remote ; then
    sed -i "/^# TG commands.*/a hostfiles=8999995" /etc/pistar-remote
fi
if ! grep -q 'reconnect=8999994' /etc/pistar-remote ; then
    sed -i "/^# TG commands.*/a reconnect=8999994" /etc/pistar-remote
fi
#

# Insert missing key/values in mmdvnhost config for my custom native NextionDriver
# 
# 5/2023 W0CHP
#
# only insert the key/values IF MMDVMHost has display type of "Nextion" defined.
if [ "`sed -nr "/^\[General\]/,/^\[/{ :l /^\s*[^#].*/ p; n; /^\[/ q; b l; }" /etc/mmdvmhost | grep "Display" | cut -d= -f 2`" = "Nextion" ]; then
    # Check if the GroupsFileSrc and DMRidFileSrc exist in the INI file
    if ! grep -q "^GroupsFileSrc=" /etc/mmdvmhost; then
        # Insert GroupsFileSrc in the NextionDriver section
        sed -i '/^\[NextionDriver\]$/a GroupsFileSrc=https://hostfiles.w0chp.net/groupsNextion.txt' /etc/mmdvmhost
    fi
    # Check if GroupsFile is set to groups.txt and change it to groupsNextion.txt
    if grep -q "^GroupsFile=groups.txt" /etc/mmdvmhost; then
        sed -i 's/^GroupsFile=groups.txt$/GroupsFile=groupsNextion.txt/' /etc/mmdvmhost
    fi
fi
#

# Add nextion halt functions
#
# 7/2023 W0CHP
#
if [ ! -f '/lib/systemd/system/stop-nextion.service' ]; then
    declare -a CURL_OPTIONS=('-Ls' '-A' "Nextion Halt Service Installer (slipstream) $uaStr")
    curl "${CURL_OPTIONS[@]}" https://wpsd-swd.w0chp.net/WPSD-SWD/W0CHP-PiStar-Installer/raw/branch/master/supporting-files/nextion-driver-term -o /usr/local/sbin/nextion-driver-term
    chmod a+x /usr/local/sbin/nextion-driver-term
    curl "${CURL_OPTIONS[@]}" https://wpsd-swd.w0chp.net/WPSD-SWD/W0CHP-PiStar-Installer/raw/branch/master/supporting-files/stop-nextion.service -o /lib/systemd/system/stop-nextion.service
    systemctl daemon-reload
    systemctl enable stop-nextion.service
fi
#

# Change default Dstar startup ref from "REF001 C" to "None", re: KC1AWV 5/21/23
#
# 5/2023 W0CHP
#
config_file="/etc/ircddbgateway"
gateway_callsign=$(grep -Po '(?<=gatewayCallsign=).*' "$config_file")
reflector1=$(grep -Po '(?<=reflector1=).*' "$config_file")
if [ "$gateway_callsign" = "M1ABC" ]; then
    new_reflector1="None"
    sed -i "s/^reflector1=.*/reflector1=$new_reflector1/" "$config_file"
fi
#

# 5/27/23: Bootstrapping backend scripts
CONN_CHECK_URI="https://wpsd-swd.w0chp.net/api/v1/repos/WPSD-SWD/W0CHP-PiStar-sbin/branches"
gitUaStr="Slipstream Task $uaStr"
conn_check() {
    local status=$(curl -L -m 6 -A "ConnCheck - $gitUaStr" --write-out %{http_code} --silent --output /dev/null "$CONN_CHECK_URI")

    if [[ $status -ge 200 && $status -lt 400 ]]; then
  	echo "ConnCheck OK: $status"
        return 0  # Status code between 200 and 399, continue
    else
        echo "ConnCheck status code is not in the expected range: $status"
        exit 1
    fi
}
repo_path="/usr/local/sbin"
cd "$repo_path" || { echo "Failed to change directory to $repo_path"; exit 1; }
if conn_check; then
    if env GIT_HTTP_CONNECT_TIMEOUT="10" env GIT_HTTP_USER_AGENT="sbin check ${gitUaStr}" git fetch origin; then
        commits_behind=$(git rev-list --count HEAD..origin/master)
        if [[ $commits_behind -gt 0 ]]; then
            if env GIT_HTTP_CONNECT_TIMEOUT="10" env GIT_HTTP_USER_AGENT="sbin update bootstrap ${gitUaStr}" git pull origin master; then
                echo "Local sbin repository updated successfully. Restarting script..."
                exec bash "$0" "$@" # Re-execute the script with the same arguments
            else
                echo "Failed to update the local sbin repository."
                exit 1
            fi
        else
            echo "Local sbin repository is up to date."
	    ## temp stuck dash hash fix
	    #gitFolder="/var/www/dashboard"
	    #cd ${gitFolder}
	    #git stash # save user config files: config/config.php config/ircddblocal.php config/language.php
	    #env GIT_HTTP_CONNECT_TIMEOUT="10" env GIT_HTTP_USER_AGENT="dashcode update bootstrap ${gitUaStr}" git --work-tree=/var/www/dashboard --git-dir=/var/www/dashboard/.git pull origin ${gitBranch}
	    #git reset --hard
	    #git checkout stash@{0} -- config/config.php config/ircddblocal.php config/language.php # restore user config files from stash
	    #git stash clear # housekeeping
        fi
    else
        echo "Failed to fetch from the remote repository."
        exit 1
    fi
else
    echo "Failed to check the HTTP status of the repository URL: $url"
    exit 1
fi

# 5/30/23: ensure www perms are correct:
cd /var/www/dashboard && chmod 755 `find  -type d`
#

# 6/2/2023: ensure lsb-release exists:
isInstalled=$(dpkg-query -W -f='${Status}' lsb-release 2>/dev/null | grep -c "ok installed")
if [[ $isInstalled -eq 0 ]]; then
  echo "lsb-release package is not installed. Installing..."
  sudo apt-get update
  sudo apt-get -y install lsb-release base-files
else
  :
fi
#

# 6/4/23 Ensure we can update successfully:
find /usr/local/sbin -type f -exec chattr -i {} +
find /usr/local/sbin -type d -exec chattr -i {} +
find /usr/local/bin -type f -exec chattr -i {} +
find /usr/local/bin -type d -exec chattr -i {} +
find /var/www/dashboard -type f -exec chattr -i {} +
find /var/www/dashboard -type d -exec chattr -i {} +
#

# ensure D-S remote control file exists and is correct - 6/6/2023
DSremoteFile="/root/.Remote Control"
passwordLine="password="
if [ -e "$DSremoteFile" ]; then
    if ! grep -q "^$passwordLine" "$DSremoteFile" || [ ! -s "$DSremoteFile" ]; then
        echo "$passwordLine""raspberry" > "$DSremoteFile"
        echo "address=127.0.0.1" >> "$DSremoteFile"
        echo "port=10022" >> "$DSremoteFile"
        echo "windowX=0" >> "$DSremoteFile"
        echo "windowY=0" >> "$DSremoteFile"
    else
	:
    fi
else
    echo "$passwordLine""raspberry" > "$DSremoteFile"
    echo "address=127.0.0.1" >> "$DSremoteFile"
    echo "port=10022" >> "$DSremoteFile"
    echo "windowX=0" >> "$DSremoteFile"
    echo "windowY=0" >> "$DSremoteFile"
fi
#

#  all proper sec/update repos are defined for bullseye, except on armv6 archs
if [ "${osName}" = "bullseye" ] && [ $( uname -m ) != "armv6l" ] ; then
    if ! grep -q 'bullseye-security' /etc/apt/sources.list ; then
        if ! apt-key list | grep -q "Debian Security Archive Automatic Signing Key (11/bullseye)" > /dev/null 2<&1; then
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 54404762BBB6E853 > /dev/null 2<&1
        fi
        echo "deb http://security.debian.org/debian-security bullseye-security main contrib non-free" >> /etc/apt/sources.list
    fi
    if ! grep -q 'bullseye-updates' /etc/apt/sources.list  ; then
        if ! apt-key list | grep -q "Debian Archive Automatic Signing Key (11/bullseye)" > /dev/null 2<&1 ; then
            apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 0E98404D386FA1D9 > /dev/null 2<&1
        fi
        echo "deb http://deb.debian.org/debian bullseye-updates main contrib non-free" >> /etc/apt/sources.list
    fi
fi
# Bulleye backports, etc. cause php-fpm segfaults on armv6 (Pi 0w 1st gen) archs...
# So we'll stick with the "normal" repos for these archs (retro buster image bugfix)
if [ $( uname -m ) == "armv6l" ] ; then
    if grep -q 'bullseye-security' /etc/apt/sources.list ; then
        sed -i '/bullseye-security/d' /etc/apt/sources.list
        sed -i '/bullseye-updates/d' /etc/apt/sources.list
        apt-get remove --purge -y php7.4*
        apt-get clean ; apt autoclean
        apt-get update
        apt-get install -y php7.4-fpm php7.4-readline php7.4-mbstring php7.4-cli php7.4-zip php7.4-opcache
        systemctl restart php7.4-fpm
    fi
fi
#

# remove dstarrepeater unit file/service - 7/2023 W0CHP
#
if [ -f '/lib/systemd/system/dstarrepeater.service' ] ; then
    systemctl stop dstarrepeater.timer
    systemctl disable dstarrepeater.timer
    systemctl stop dstarrepeater.service
    systemctl disable dstarrepeater.service
    rm -f /lib/systemd/system/dstarrepeater.timer
    rm -f /lib/systemd/system/dstarrepeater.service
    systemctl daemon-reload
fi
if grep -qo 'dstarrepeater =' /etc/pistar-release ; then
    sed -i '/dstarrepeater =/d' /etc/pistar-release
fi
#

# Increase /run ram disk a bit for better updating. 7/2023 W0CHP - thanks KF4HZU!
#
sed -i 's|^tmpfs[[:blank:]]*/run[[:blank:]]*tmpfs[[:blank:]]*nodev,noatime,nosuid,mode=1777,size=32m[[:blank:]]*0[[:blank:]]*0$|tmpfs                   /run                    tmpfs   nodev,noatime,nosuid,mode=1777,size=64m         0       0|' /etc/fstab
#

# incr. php session storage to 128k  - thanks KC1AWV!
sed -i 's|^tmpfs[[:blank:]]*/var/lib/php/sessions[[:blank:]]*tmpfs[[:blank:]]*nodev,noatime,nosuid,mode=0777,size=64k[[:blank:]]*0[[:blank:]]*0$|tmpfs                   /var/lib/php/sessions   tmpfs   nodev,noatime,nosuid,mode=0777,size=128k        0       0|' /etc/fstab

# Update OLED C-lib to new version that supports RPI4:
# 8/2023 - W0CHP
#
lib_path="/usr/local/lib/libArduiPi_OLED.so.1.0"
target_timestamp=$(date -d "2023-08-20" +%s)
timestamp=$(stat -c %Y "$lib_path" 2>/dev/null)
size=$(stat -c %s "$lib_path" 2>/dev/null)
threshold_size=63896
if [[ $(platformDetect.sh) != *"sun8i"* ]]; then
    if [ -n "$timestamp" ] && [ -n "$size" ]; then
	if [ "$timestamp" -lt "$target_timestamp" ] && [ "$size" -lt "$threshold_size" ]; then
	    mv /usr/local/lib/libArduiPi_OLED.so.1.0 /usr/local/lib/libArduiPi_OLED.so.1.0.bak
	    rm -f /usr/local/lib/libArduiPi_OLED.so.1
 	    declare -a CURL_OPTIONS=('-Ls' '-A' "libArduiPi_OLED.so updater $uaStr")
	    curl "${CURL_OPTIONS[@]}" -o /usr/local/lib/libArduiPi_OLED.so.1.0 https://wpsd-swd.w0chp.net/WPSD-SWD/W0CHP-PiStar-Installer/raw/branch/master/supporting-files/libArduiPi_OLED.so.1.0
	    ln -s /usr/local/lib/libArduiPi_OLED.so.1.0 /usr/local/lib/libArduiPi_OLED.so.1
	    systemctl restart mmdvmhost.service
        else
	    :
        fi
    else
	echo "$lib_path not found or unable to get its information."
    fi
fi
# fix for weird symlink issue
libOLEDlibsymlink="libArduiPi_OLED.so.1"
libOLEDoldTarget="libArduiPi_OLED.so.1.0.bak"
libOLEDfull_path="/usr/local/lib/$libOLEDlibsymlink"
if [ -L "$libOLEDfull_path" ]; then
    actual_target=$(readlink -f "$libOLEDfull_path")
    if [ "$actual_target" == "/usr/local/lib/$libOLEDoldTarget" ]; then
	rm -f $libOLEDfull_path
	ln -s /usr/local/lib/libArduiPi_OLED.so.1.0 /usr/local/lib/libArduiPi_OLED.so.1
        systemctl restart mmdvmhost.service
    fi
fi
#

# Update /etc/issue - 9/2023 W0CHP
#
if ! grep -q 'W0CHP' /etc/issue ; then
    declare -a CURL_OPTIONS=('-Ls' '-A' "/etc/issue updater $uaStr")
    curl "${CURL_OPTIONS[@]}" -o /etc/issue https://wpsd-swd.w0chp.net/WPSD-SWD/W0CHP-PiStar-Installer/raw/branch/master/supporting-files/issue
fi
#

# legacy cleanups
if [ -f '/usr/sbin/WPSD-Installer' ]; then
    rm -rf /usr/sbin/WPSD-Installer
fi

# avahi service names
if grep -q 'Pi-Star Web Interface' /etc/avahi/services/http.service ; then
    sed -i 's/Pi-Star Web Interface/WPSD Web Interface/g' /etc/avahi/services/http.service
    sed -i 's/Pi-Star SSH/WPSD SSH/g' /etc/avahi/services/ssh.service
    systemctl restart avahi-daemon.socket
    systemctl restart avahi-daemon.service
fi

# update daily cron shuffle rules in rc.local
if grep -q 'shuf -i 3-4' $rc_local_file ; then
  sed -i "s/shuf -i 3-4/shuf -i 2-4/g" $rc_local_file
fi

# add slipstream to rc.local
# Define the correct entry
correct_entry="nohup /usr/local/sbin/slipstream-tasks.sh &"
# Check if the correct entry already exists in $rc_local_file
if grep -q -x "$correct_entry" $rc_local_file; then
  :
else
  # Remove the legacy entries and add the correct entry
  sed -i '/nohup nohup.*&/d' $rc_local_file
  sed -i '/\/usr\/local\/sbin\/slipstream-tasks\.sh/d' $rc_local_file
  sed -i '/# slipstream tasks/a '"$correct_entry"'' $rc_local_file
fi

# cleanup legacy motdgen
if grep -q 'pistar-motdgen' $rc_local_file ; then
   sed -i 's/pistar-motdgen/motdgen/g' $rc_local_file
fi

# add sys cache to rc.local and exec
if grep -q 'pistar-hwcache' $rc_local_file ; then
    sed -i '/# cache hw info/,/\/usr\/local\/sbin\/pistar-hwcache/d' $rc_local_file
    sed -i '/^\/usr\/local\/sbin\/motdgen/a \\n# cache hw info\n\/usr/local/sbin/.wpsd-sys-cache' $rc_local_file
    /usr/local/sbin/.wpsd-sys-cache
else
    /usr/local/sbin/.wpsd-sys-cache
fi

# Add wpsd-service bash completion & remove legacy one
OLD_DEST="/usr/share/bash-completion/completions/pistar-services"
DEST="/usr/share/bash-completion/completions/wpsd-services"
COMPLETION_CONFIG="/etc/bash_completion.d/wpsd-services"
if [ -f "$OLD_DEST" ]; then
    sudo rm -f "$OLD_DEST"
    echo "Removed $OLD_DEST"
fi
if [ -f "$DEST" ]; then
    sudo rm -f "$DEST"
    echo "Removed $DEST"
fi
if [ ! -f "$COMPLETION_CONFIG" ]; then
    echo "#!/bin/bash" | sudo tee "$COMPLETION_CONFIG" >/dev/null
    echo "" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "_wpsd_services()" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "{" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "    local cur prev words cword" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "    _init_completion -n = || return" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "    _expand || return 0" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "    COMPREPLY=( \$( compgen -W 'start stop restart fullstop status' -- \"\$cur\" ) )" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "} &&" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "complete -F _wpsd_services wpsd-services" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    echo "" | sudo tee -a "$COMPLETION_CONFIG" >/dev/null
    sudo chown root:root "$COMPLETION_CONFIG"
    sudo chmod 0644 "$COMPLETION_CONFIG"
    echo "New completion file created"
fi
if [ -f /devnull ] ; then # ugh - cleanup prev. typo.
    rm -f /devnull
fi

# Armbian for NanoPi Neo / OrangePi Zero handling
if [ -f "$armbian_env_file" ] && [[ $(grep "console=serial" $armbian_env_file) ]] ; then
    sed -i '/console=serial/d' $armbian_env_file
fi
ttyama0_line="# OPi/NanoPi serial ports:"
ttyama0_line+="\nmknod \"/dev/ttyAMA0\" c 4 65"
ttyama0_line+="\nchown .dialout /dev/ttyAMA0"
ttyama0_line+="\nchmod 660 /dev/ttyAMA0\n"
ssh_keys_line="# AutoGenerate SSH keys if they are missing"
if [ -f "$armbian_env_file" ] && ! grep -q "ttyAMA0" "$rc_local_file"; then
    sed -i "/$ssh_keys_line/i $ttyama0_line" "$rc_local_file"
fi

# remove last heard data manager; taxing, inaccurate, unreliable, and; mqtt coming ;-)
if [ -f /lib/systemd/system/mmdvm-log-backup.service ] ; then
    systemctl stop mmdvm-log-backup.timer > /dev/null 2<&1
    systemctl disable mmdvm-log-backup.timer > /dev/null 2<&1
    systemctl stop mmdvm-log-backup.service > /dev/null 2<&1
    systemctl disable mmdvm-log-backup.service > /dev/null 2<&1
    systemctl stop mmdvm-log-restore.service > /dev/null 2<&1
    systemctl disable mmdvm-log-restore.service > /dev/null 2<&1
    systemctl stop mmdvm-log-shutdown.service > /dev/null 2<&1
    systemctl disable mmdvm-log-shutdown.service > /dev/null 2<&1
    rm -rf //lib/systemd/system/mmdvm-log-* > /dev/null 2<&1
    systemctl daemon-reload > /dev/null 2<&1
    rm -rf /home/pi-star/.backup-mmdvmhost-logs > /dev/null 2<&1
fi

# more rc.local updates...
if grep -q 'pistar-mmdvmhshatreset' $rc_local_file ; then
    sed -i 's/pistar-mmdvmhshatreset/wpsd-modemreset/g' $rc_local_file
    sed -i 's/GPIO Pins on Pi4 Only/GPIO Pins on Pi4, Pi5 etc. only/g' $rc_local_file
fi

# NanoPi/OPi/Armbian vnstat & late-init wlan handling:
if [ -f "$armbian_env_file" ] ; then
    if ip link show eth0 | grep -q "state UP" ; then
	:
    else 
	# Check if there's an active network connection on wlan0
	if ip link show wlan0 | grep -q "state UP" ; then
	    # Check if the error message is present for wlan0
	    if vnstat -i wlan0 2>&1 | grep -q "Error: Interface \"wlan0\" not found in database." ; then
		service vnstat stop
		rm -f /var/lib/vnstat/*
		service vnstat start
	    fi
	fi
    fi
fi

# ensure hostfiles are updated more regularly
/usr/local/sbin/HostFilesUpdate.sh &> /dev/null
