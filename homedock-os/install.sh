#!/bin/bash

anim_t() {
  TEXT=$1
  CMD=$2
  (eval "$CMD" >/dev/null 2>&1) &
  CMD_PID=$!
  chars="/-\\|"
  echo -n "$TEXT "
  while [ -d /proc/$CMD_PID ]; do
    for i in {0..3}; do
      char=${chars:i:1}
      echo -ne "\\r $char $TEXT"
      sleep 0.2
    done
  done
  echo -e "\\r ✓ $TEXT          "
  wait $CMD_PID
}

# Verify and install apt package
package_exists_and_anim() {
  package=$1
  text=$2

  dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"
  if [ $? -eq 0 ]; then
    echo " ✓ $text is already installed"
  else
    anim_t "Installing $text..." "sudo apt-get install -y $package"
  fi
}

# Verify and install git
install_git() {
  if ! command -v git &>/dev/null; then
    anim_t "Installing Git..." "sudo apt-get install -y git"
  else
    echo " ✓ Git is already installed"
  fi
}

# Check if sudo is installed
if ! command -v sudo &>/dev/null; then
  echo "Error: sudo is not installed. Please install sudo and try again."
  exit 1
fi

# Check if user has sudo privileges
if ! sudo -n true 2>/dev/null; then
  echo "You must have sudo privileges to run this script."
  sudo -v || exit 1
fi

echo "                                      "
echo "                                      "
echo "            @@@@@@@@@@@@@@@@@@@@@@@@  "
echo "           @@@@@@@@@@@@@@@@@@@@@@@@@  "
echo "          @@@@                        "
echo "         @@@@   @@@@@@@@@@@@@@@@@@@@  "
echo "        @@@@   @@@                    "
echo "        @@@   @@@   @@@@@@@@@@@@@     "
echo "       @@@   @@@*  @@@@      @@@*  @  "
echo "      @@@   @@@@  @@@@      @@@@  @@  "
echo "     @@@*  @@@@  (@@@      @@@@@@@@@  "
echo "    @@@@  @@@@   @@@      //////////  "
echo "   @@@@  @@@@   @@@                   "
echo "  @@@@  #@@@   @@@                    "
echo " @@@@   @@@   @@@                     "
echo "                                      "
echo " ⌂ Installing HomeDock OS...               "
echo ""
echo " i Sit back and relax... It may take a while!"
echo ""

# Get current directory
CURRENT_DIR=$(pwd)
echo " i Current path:"
echo "   $CURRENT_DIR"
echo ""

# Install git
install_git

# Download HomeDock OS Repository from GitHub
anim_t "Downloading HomeDock OS Repository from GitHub " "git clone https://github.com/BansheeTech/HomeDockOS.git"

# Check if HomeDock OS folder exists
cd HomeDockOS || {
  echo "HomeDock OS folder not found"
  exit 1
}
echo " ✓ Switching to $CURRENT_DIR/HomeDockOS Directory..."
echo ""

BIN_DIR=$(pwd)
echo " i Installation path:"
echo "   $BIN_DIR"
echo ""

# Python Virtual Environment Path
VENV_PATH="$BIN_DIR/venv"
echo " i Python Virtual Environment Path:"
echo "   $VENV_PATH"
echo ""

echo " i Checking and installing apt dependencies..."

# Install apt dependencies
package_exists_and_anim "docker" "Docker"
package_exists_and_anim "docker-compose" "Docker-Compose"
package_exists_and_anim "python3" "Python3"
package_exists_and_anim "python3-pip" "PIP"
package_exists_and_anim "python3-venv" "Python3-Venv"

echo ""
echo " i Setting up Python virtual environment..."

# Create Python virtual environment
if [ ! -d "venv" ]; then
  anim_t "Creating Python virtual environment..." "python3 -m venv venv"
else
  echo " ✓ Python virtual environment already exists"
fi

echo ""
echo " i Checking and installing pip dependencies..."

anim_t "Installing dependencies..." "venv/bin/pip install -r requirements.txt"

# Generate HomeDock OS service file
echo ""
echo " i Generating HomeDock OS service file..."
echo "[Unit]" >homedock.service
echo "Description=HomeDock Auto-Boot Service" >>homedock.service
echo "After=network.target" >>homedock.service
echo "[Service]" >>homedock.service
echo "User=root" >>homedock.service
echo "TimeoutStartSec=60" >>homedock.service
echo "WorkingDirectory=${BIN_DIR}" >>homedock.service
echo "ExecStartPre=/bin/sleep 15" >>homedock.service
echo "ExecStart=$VENV_PATH/bin/python3 \"${BIN_DIR}/homedock.py\"" >>homedock.service
echo "Restart=always" >>homedock.service
echo "[Install]" >>homedock.service
echo "WantedBy=multi-user.target" >>homedock.service

# Check if service file exists
echo ""
echo " i Checking if service file exists..."
if [ -e "homedock.service" ]; then
  echo "   File exists! Copying it to /etc/systemd/system/..."
  sudo cp homedock.service /etc/systemd/system/
else
  echo "   File doesn't exists! Stopping generation..."
  exit 0
fi

# Enable HomeDock OS service
echo ""
echo " i Checking if HomeDock OS service is ready..."
if [ -e "/etc/systemd/system/homedock.service" ]; then
  echo "   Service exists!"
  sudo systemctl enable homedock.service
else
  echo "   Service doesn't exists! Stopping generation..."
  exit 0
fi

# Disclaimer HomeDock OS Running from Command Line
echo ""
echo " i We're running HomeDock OS from the command line for the first time!"
echo " i Modify your settings by logging in first then restart"
echo ""
echo " i Manually run HomeDock OS using the following command"
echo "   sudo $VENV_PATH/bin/python3 $BIN_DIR/homedock.py"
echo ""
echo " i If you reboot HomeDock OS service will autostart!"
echo ""

# Run HomeDock OS
sudo $VENV_PATH/bin/python3 $BIN_DIR/homedock.py
