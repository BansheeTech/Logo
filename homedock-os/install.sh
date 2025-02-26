#!/bin/bash
# HomeDock OS Installer 1.0.32.228

set -e

# [===================================================================================================]
#                                           Script Functions
# [===================================================================================================]

# Print a blank line :3
clrf() {
  printf "\n"
}

# Spinner animation for background tasks
animate_blink() {
  local TEXT=$1
  local CMD=$2
  (eval "$CMD" >/dev/null 2>&1) &
  local CMD_PID=$!
  local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  printf "%s " "$TEXT"
  while kill -0 $CMD_PID 2>/dev/null; do
    for ((i = 0; i < ${#chars}; i++)); do
      printf "\\r %s %s" "${chars:i:1}" "$TEXT"
      sleep 0.07
    done
  done
  wait $CMD_PID
  printf "\\r ✓ %s\n" "$TEXT"
}

# Check and install apt packages
package_exists() {
  local package=$1
  local text=$2

  if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
    printf " ✓ %s is already installed\n" "$text"
  else
    animate_blink "Installing $text..." "sudo apt-get install -y $package"
  fi
}

# Detect distribution and set Docker package accordingly
detect_distro() {
  local timeout=10
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    printf " ✓ Detected Linux distribution: %s\n" "$PRETTY_NAME"
    case "$ID" in
    ubuntu) DOCKER_PKG="docker.io" ;;
    debian) DOCKER_PKG="docker" ;;
    *)
      clrf
      printf " ! This installer has been tested only on Debian and Ubuntu distributions.\n"
      printf " i The installation *may fail* or cause unexpected behavior.\n"

      for ((i = timeout; i > 0; i--)); do
        printf "\r ? Do you still want to continue? (Y/N) [Auto-No in %2d seconds]:" "$i"
        read -t 1 -n 1 response </dev/tty && break
      done
      printf "\n"

      response=${response:-n}

      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        clrf
        printf " x Installation aborted by user due to unsupported distribution.\n"
        clrf
        exit 1
      fi
      DOCKER_PKG="docker"
      clrf
      printf " ✓ Proceeding with installation on unsupported distribution: %s\n" "$PRETTY_NAME"
      clrf
      ;;
    esac
  else
    printf " i We couldn't detect your actual distribution because /etc/os-release was not found.\n"
    printf " i The installation *may fail* or cause unexpected behavior.\n"

    for ((i = timeout; i > 0; i--)); do
      printf "\r ? Do you still want to continue? (Y/N) [Auto-No in %2d seconds]:" "$i"
      read -t 1 -n 1 response </dev/tty && break
    done
    printf "\n"

    response=${response:-n}

    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      clrf
      printf " x Installation aborted by user due to unknown distribution.\n"
      clrf
      exit 1
    fi
    DOCKER_PKG="docker"
    clrf
    printf " ✓ Proceeding with installation.\n"
  fi
}

# Prompt user with timeout and countdown animation
prompt_with_timeout() {
  local timeout=10
  clrf
  printf " i The following dependencies will be installed locally if not found: \n * git, %s, docker-compose, python3, python3-pip, python3-venv\n\n" "$DOCKER_PKG"

  for ((i = timeout; i > 0; i--)); do
    printf "\\r ? Do you want to proceed? (Y/N) [Auto-Yes in %2d seconds]:" "$i"
    read -t 1 -n 1 response </dev/tty && break
  done
  printf "\\n"

  response=${response:-y}
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    clrf
    printf " ! Installation aborted by user.\n\n"
    exit 1
  fi
}

# Check and install git
install_git() {
  if ! command -v git &>/dev/null; then
    animate_blink "Installing Git..." "sudo apt-get install -y git"
  else
    printf " ✓ Git is already installed\n"
  fi
}

# Check sudo availability
check_sudo() {
  if ! command -v sudo &>/dev/null; then
    clrf
    printf " ✗ Error: sudo is not installed. Please install sudo and try again.\n"
    exit 1
  fi
  if ! sudo -n true 2>/dev/null; then
    clrf
    printf " i You must have sudo privileges to run this script.\n"
    sudo -v || exit 1
  fi
}

# Install pip dependencies with per-package feedback
install_pip_dependencies() {
  if [ ! -f "requirements.txt" ]; then
    clrf
    printf " ! requirements.txt not found. Ensure it exists in the HomeDockOS directory.\n"
    exit 1
  fi

  while IFS= read -r package || [ -n "$package" ]; do
    if [[ -n "$package" && ! "$package" =~ ^# ]]; then
      animate_blink "Installing $package" "venv/bin/pip install $package"
    fi
  done <requirements.txt
}

display_logo() {
  clear
  cat <<"EOF"

            @@@@@@@@@@@@@@@@@@@@@@@@  
           @@@@@@@@@@@@@@@@@@@@@@@@@  
          @@@@                        
         @@@@   @@@@@@@@@@@@@@@@@@@@  
        @@@@   @@@                    
        @@@   @@@   @@@@@@@@@@@@@     
       @@@   @@@*  @@@@      @@@*  @  
      @@@   @@@@  @@@@      @@@@  @@  
     @@@*  @@@@  (@@@      @@@@@@@@@  
    @@@@  @@@@   @@@      //////////  
   @@@@  @@@@   @@@                   
  @@@@  #@@@   @@@                    
 @@@@   @@@   @@@                     

 Repo:    https://github.com/BansheeTech/HomeDockOS
 Web:     https://www.homedock.cloud
 Docs:    https://docs.homedock.cloud
 Support: support@homedock.cloud

EOF
  printf " ⌂ Installing HomeDock OS...\n"
  printf " i Sit back and relax... It may take a while!\n"
  clrf
}

# Prompt user and handle full service installation logic
prompt_service_installation() {
  local VENV_PATH=$1
  local WORK_DIR=$2
  local CURRENT_DIR=$3
  local timeout=10
  local SERVICE_PATH="$CURRENT_DIR/HomeDockOS/homedock.service"

  printf " i HomeDock OS can be configured to auto-start on boot.\n"
  printf " i This will create a service in /etc/systemd/system\n"

  cat <<EOF >"$SERVICE_PATH"
[Unit]
Description=HomeDock Auto-Boot Service
After=network.target

[Service]
User=root
TimeoutStartSec=60
WorkingDirectory=$WORK_DIR
ExecStartPre=/bin/sleep 15
ExecStart=$VENV_PATH/bin/python3 "$WORK_DIR/homedock.py"
Restart=always

[Install]
WantedBy=multi-user.target
EOF

  clrf
  for ((i = timeout; i > 0; i--)); do
    printf "\r ? Do you want to install and enable the service? (Y/N) [Auto-Yes in %2d seconds]:" "$i"
    read -t 1 -n 1 response </dev/tty && break
  done
  printf "\n"

  response=${response:-y}

  if [[ "$response" =~ ^[Yy]$ ]]; then
    clrf
    printf " i Copying service file to /etc/systemd/system/...\n"
    sudo cp "$SERVICE_PATH" /etc/systemd/system/
    sudo systemctl enable homedock.service
    printf " ✓ HomeDock OS service has been enabled and will start at boot!\n"
  else
    clrf
    printf " ! Skipping service installation as per user choice.\n"
    printf " i You can manually enable it later with:\n"
    printf "     sudo cp \"$SERVICE_PATH\" /etc/systemd/system/\n"
    printf "     sudo systemctl enable homedock.service && sudo systemctl start homedock.service\n"
  fi
}

# Verify Python virtual environment creation
check_virtualenv_created() {
  local VENV_PATH=$1
  if [ ! -d "$VENV_PATH" ]; then
    printf " ! Error: Virtual environment creation failed at %s.\n" "$VENV_PATH"
    exit 1
  fi
}

# Verify network connection
check_network_connection() {
  if ! ping -c 1 github.com &>/dev/null; then
    printf " ! Error: No network connection. Please check your Internet.\n"
    exit 1
  fi
}

# Handle git clone with animation
handle_repo_clone() {
  local timeout=10
  if [ -d "HomeDockOS" ]; then
    clrf
    printf " ! HomeDockOS directory already exists.\n"

    for ((i = timeout; i > 0; i--)); do
      printf "\r ? Do you want to re-create it? All data will be erased! (Y/N) [Auto-No in %2d seconds]:" "$i"
      read -t 1 -n 1 response </dev/tty && break
    done
    printf "\n"

    response=${response:-n}

    if [[ "$response" =~ ^[Yy]$ ]]; then
      rm -rf HomeDockOS
      animate_blink "Re-cloning HomeDock OS Repository from GitHub" \
        "git clone https://github.com/BansheeTech/HomeDockOS.git"
    else
      clrf
      printf " ✗ Couldn't proceed because HomeDockOS folder already exists.\n"
      clrf
      exit 1
    fi
  else
    animate_blink "Downloading HomeDock OS Repository from GitHub" \
      "git clone https://github.com/BansheeTech/HomeDockOS.git"
  fi
}

# [===================================================================================================]
#                                             Main Logic
# [===================================================================================================]

main() {
  display_logo
  check_sudo
  detect_distro
  check_network_connection

  local CURRENT_DIR=$(pwd)
  printf " ✓ HomeDock OS Installation Path: %s\n" "$CURRENT_DIR"/HomeDockOS

  prompt_with_timeout

  install_git

  handle_repo_clone

  cd HomeDockOS || {
    clrf
    printf " ✗ HomeDock OS folder not found\n"
    exit 1
  }

  printf " ✓ Switched to %s Directory...\n" "$(pwd)"
  clrf

  printf " i Checking and installing apt dependencies...\n"
  for pkg in "$DOCKER_PKG" docker-compose python3 python3-pip python3-venv; do
    package_exists "$pkg" "${pkg^}"
  done

  clrf

  local VENV_PATH="$(pwd)/venv"
  printf " i Python Virtual Environment Path: %s\n" "$VENV_PATH"

  printf " i Setting up Python virtual environment...\n"
  [ ! -d "venv" ] && animate_blink "Creating Python virtual environment..." "python3 -m venv venv" || printf " ✓ Python virtual environment already exists\n"
  clrf

  check_virtualenv_created "$VENV_PATH"

  if [ ! -f "requirements.txt" ]; then
    clrf
    printf " ✗ requirements.txt not found. Ensure it exists in the HomeDockOS directory.\n"
    exit 1
  fi

  printf " i Installing Python dependencies...\n"
  install_pip_dependencies
  clrf

  prompt_service_installation "$VENV_PATH" "$(pwd)" "$CURRENT_DIR"

  clrf
  printf "\033[1;30;47m ✓ Running HomeDock OS for the first time! \033[0m\n"
  clrf

  sudo $VENV_PATH/bin/python3 "$(pwd)/homedock.py"
}

main
