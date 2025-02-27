#!/bin/bash
# HomeDock OS Installer 1.0.32.228-3

# [===================================================================================================]
#                                            Script Functions
# [===================================================================================================]

((EUID)) && sugo="sudo" || sugo=""

# Print a blank line :3
____CLRF____() {
  printf "\n"
}

# Spinner animation for background tasks
____ANIMATE_BLINK____() {
  local TEXT=$1
  local CMD=$2
  (eval "$CMD" >/dev/null 2>&1) &
  local CMD_PID=$!
  local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
  printf "%s " "$TEXT"
  while kill -0 $CMD_PID 2>/dev/null; do
    for ((i = 0; i < ${#chars}; i++)); do
      printf "\\r %s %s" "${chars:i:1}" "$TEXT"
      sleep 0.06
    done
  done
  wait $CMD_PID
  printf "\\r ✓ %s\n" "$TEXT"
}

# Check and install apt packages
____PACKAGE_EXISTS____() {
  local package=$1
  local text=$2

  if dpkg-query -W -f='${Status}' "$package" 2>/dev/null | grep -q "install ok installed"; then
    printf " ✓ %s is already installed\n" "$text"
  else
    ____ANIMATE_BLINK____ "Installing $text..." "${sugo} ${PACKAGE_MANAGER} install -y $package"
  fi
}

# Detect distribution and set Docker package accordingly
____DETECT_DISTRO____() {
  local timeout=10
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    printf " ✓ Detected Linux distribution: %s\n" "$PRETTY_NAME"

    if [[ "$ID" != "debian" && "$ID" != "ubuntu" ]]; then
      ____CLRF____
      printf " ! This installer has been tested mainly on Debian and Ubuntu distributions.\n"
      printf " i The installation *may fail* or cause unexpected behavior.\n"

      for ((i = timeout; i > 0; i--)); do
        printf "\r ? Do you still want to continue? (Y/N) [Auto-No in %2d seconds]:" "$i"
        read -t 1 -n 1 response </dev/tty && break
      done
      ____CLRF____

      response=${response:-n}
      if [[ ! "$response" =~ ^[Yy]$ ]]; then
        ____CLRF____
        printf " x Installation aborted due to unknown distribution.\n"
        ____CLRF____
        exit 1
      fi
    fi

    case "$ID" in
    debian)
      if [[ "$VERSION_ID" =~ ^(8|9|10)\. ]]; then
        ____CLRF____
        printf " ✗ Debian %s is not supported. Please use Debian 11 or later.\n" "$VERSION_ID"
        ____CLRF____
        exit 1
      fi
      PACKAGE_MANAGER="apt-get"
      DOCKER_PKG="docker"
      COMPOSE_PKG="docker-compose"
      ;;
    ubuntu)
      if [[ "$VERSION_ID" =~ ^(16|18|20)\. ]]; then
        ____CLRF____
        printf " ✗ Ubuntu %s is not supported. Please use Ubuntu 22.04 or later.\n" "$VERSION_ID"
        ____CLRF____
        exit 1
      fi
      PACKAGE_MANAGER="apt-get"
      DOCKER_PKG="docker.io"
      COMPOSE_PKG="docker-compose"
      ;;
    raspbian)
      PACKAGE_MANAGER="apt-get"
      DOCKER_PKG="docker.io"
      COMPOSE_PKG="docker-compose"
      ;;
    centos)
      PACKAGE_MANAGER="yum"
      DOCKER_PKG="docker"
      COMPOSE_PKG="docker-compose"
      ;;
    opensuse* | sles)
      PACKAGE_MANAGER="zypper"
      DOCKER_PKG="docker"
      COMPOSE_PKG="docker-compose"
      ;;
    *)

      PACKAGE_MANAGER="apt-get"
      DOCKER_PKG="docker"
      COMPOSE_PKG="docker-compose"
      ____CLRF____
      printf " ✓ Proceeding with installation on unsupported distribution: %s\n" "$PRETTY_NAME"
      ____CLRF____
      ;;
    esac
  else
    printf " i We couldn't detect your actual distribution because /etc/os-release was not found.\n"
    printf " i The installation *may fail* or cause unexpected behavior.\n"

    for ((i = timeout; i > 0; i--)); do
      printf "\r ? Do you still want to continue? (Y/N) [Auto-No in %2d seconds]:" "$i"
      read -t 1 -n 1 response </dev/tty && break
    done
    ____CLRF____

    response=${response:-n}
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
      ____CLRF____
      printf " x Installation aborted due to unknown distribution.\n"
      ____CLRF____
      exit 1
    fi

    PACKAGE_MANAGER="apt-get"
    DOCKER_PKG="docker"
    COMPOSE_PKG="docker-compose"

    ____CLRF____
    printf " ✓ Proceeding with installation.\n"
  fi
  printf " ✓ Using default package manager: %s\n" "$PACKAGE_MANAGER"

}

# Verify package manager availability
____VERIFY_PACKAGE_MANAGER____() {
  if ! command -v "$PACKAGE_MANAGER" &>/dev/null; then
    ____CLRF____
    printf " ✗ Error: Detected package manager (%s) is not available on this system.\n" "$PACKAGE_MANAGER"
    ____CLRF____
    exit 1
  fi
}

# Prompt user with timeout and countdown animation
____PROMPT_WITH_TIMEOUT____() {
  local timeout=10
  ____CLRF____
  printf " i The following dependencies will be installed locally if not found: \n * git, %s, %s, python3, python3-pip, python3-venv\n\n" "$DOCKER_PKG" "$COMPOSE_PKG"

  for ((i = timeout; i > 0; i--)); do
    printf "\\r ? Do you want to proceed? (Y/N) [Auto-Yes in %2d seconds]:" "$i"
    read -t 1 -n 1 response </dev/tty && break
  done
  printf "\\n"

  response=${response:-y}
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
    ____CLRF____
    printf " ! Installation aborted by user.\n\n"
    exit 1
  fi
}

# Check and install git
____INSTAL_GIT____() {
  if ! command -v git &>/dev/null; then
    ____ANIMATE_BLINK____ "Installing Git..." "${sugo} ${PACKAGE_MANAGER} install -y git"
  else
    printf " ✓ Git is already installed\n"
  fi
}

# Check sudo availability
____CHECK_SUDO____() {
  if [[ -z "$sugo" ]]; then
    return
  fi

  if ! command -v ${sugo} &>/dev/null; then
    ____CLRF____
    printf " ✗ Error: sudo is not installed. Please install sudo and try again.\n"
    exit 1
  fi

  if ! ${sugo} -n true 2>/dev/null; then
    ____CLRF____
    printf " i You must have sudo privileges to run this script.\n"
    ${sugo} -v || exit 1
  fi
}

# Install pip dependencies with package feedback
____INSTALL_PIP_DEPS____() {
  if [ ! -f "requirements.txt" ]; then
    ____CLRF____
    printf " ! requirements.txt not found. Ensure it exists in the HomeDockOS directory.\n"
    exit 1
  fi

  while IFS= read -r package || [ -n "$package" ]; do
    if [[ -n "$package" && ! "$package" =~ ^# ]]; then
      ____ANIMATE_BLINK____ "Installing $package" "venv/bin/pip install $package"
    fi
  done <requirements.txt
}

____DISPLAY_LOGO____() {
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
  ____CLRF____
}

# Prompt user and handle full service installation logic
____PROMPT_SERVICE_INSTALLATION____() {
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

  ____CLRF____
  for ((i = timeout; i > 0; i--)); do
    printf "\r ? Do you want to install and enable the service? (Y/N) [Auto-Yes in %2d seconds]:" "$i"
    read -t 1 -n 1 response </dev/tty && break
  done
  ____CLRF____

  response=${response:-y}

  if [[ "$response" =~ ^[Yy]$ ]]; then
    ____CLRF____
    printf " i Copying service file to /etc/systemd/system/...\n"
    ${sugo} cp "$SERVICE_PATH" /etc/systemd/system/
    ${sugo} systemctl enable homedock.service
    printf " ✓ HomeDock OS service has been enabled and will start at boot!\n"
  else
    ____CLRF____
    printf " ! Skipping service installation as per user choice.\n"
    printf " i You can manually enable it later with:\n"
    printf "     ${sugo} cp \"$SERVICE_PATH\" /etc/systemd/system/\n"
    printf "     ${sugo} systemctl enable homedock.service && ${sugo} systemctl start homedock.service\n"
  fi
}

# Verify Python virtual environment creation
____CHECK_VIRTUALENV_CREATED____() {
  local VENV_PATH=$1
  if [ ! -d "$VENV_PATH" ]; then
    printf " ! Error: Virtual environment creation failed at %s.\n" "$VENV_PATH"
    exit 1
  fi
}

# Verify network connection
____CHECK_NETWORK_CONNECTION____() {
  if ! ping -c 1 github.com &>/dev/null; then
    printf " ! Error: No network connection. Please check your Internet.\n"
    exit 1
  fi
}

# Handle git clone with animation
____HANDLE_REPO_CLONE____() {
  local timeout=10
  if [ -d "HomeDockOS" ]; then
    ____CLRF____
    printf " ! HomeDockOS directory already exists.\n"

    for ((i = timeout; i > 0; i--)); do
      printf "\r ? Do you want to re-create it? All data will be erased! (Y/N) [Auto-No in %2d seconds]:" "$i"
      read -t 1 -n 1 response </dev/tty && break
    done
    ____CLRF____

    response=${response:-n}

    if [[ "$response" =~ ^[Yy]$ ]]; then
      rm -rf HomeDockOS
      ____ANIMATE_BLINK____ "Re-cloning HomeDock OS Repository from GitHub" \
        "git clone https://github.com/BansheeTech/HomeDockOS.git"
    else
      ____CLRF____
      printf " ✗ Couldn't proceed because HomeDockOS folder already exists.\n"
      ____CLRF____
      exit 1
    fi
  else
    ____ANIMATE_BLINK____ "Downloading HomeDock OS Repository from GitHub" \
      "git clone https://github.com/BansheeTech/HomeDockOS.git"
  fi
}

# [===================================================================================================]
#                                             Main Logic
# [===================================================================================================]

____MAIN____() {
  ____DISPLAY_LOGO____
  ____CHECK_SUDO____
  ____DETECT_DISTRO____
  ____VERIFY_PACKAGE_MANAGER____
  ____CHECK_NETWORK_CONNECTION____

  local CURRENT_DIR=$(pwd)
  printf " ✓ HomeDock OS Installation Path: %s\n" "$CURRENT_DIR"/HomeDockOS

  ____PROMPT_WITH_TIMEOUT____

  ____INSTAL_GIT____

  ____HANDLE_REPO_CLONE____

  cd HomeDockOS || {
    ____CLRF____
    printf " ✗ HomeDock OS folder not found\n"
    exit 1
  }

  printf " ✓ Switched to %s Directory...\n" "$(pwd)"
  ____CLRF____

  printf " i Checking and installing apt dependencies...\n"
  for pkg in "$DOCKER_PKG" docker-compose python3 python3-pip python3-venv; do
    ____PACKAGE_EXISTS____ "$pkg" "${pkg^}"
  done

  ____CLRF____

  local VENV_PATH="$(pwd)/venv"
  printf " i Python Virtual Environment Path: %s\n" "$VENV_PATH"

  printf " i Setting up Python virtual environment...\n"
  [ ! -d "venv" ] && ____ANIMATE_BLINK____ "Creating Python virtual environment..." "python3 -m venv venv" || printf " ✓ Python virtual environment already exists\n"
  ____CLRF____

  ____CHECK_VIRTUALENV_CREATED____ "$VENV_PATH"

  if [ ! -f "requirements.txt" ]; then
    ____CLRF____
    printf " ✗ requirements.txt not found. Ensure it exists in the HomeDockOS directory.\n"
    exit 1
  fi

  printf " i Installing Python dependencies...\n"
  ____INSTALL_PIP_DEPS____
  ____CLRF____

  ____PROMPT_SERVICE_INSTALLATION____ "$VENV_PATH" "$(pwd)" "$CURRENT_DIR"

  ____CLRF____
  printf "\033[1;30;47m ✓ Running HomeDock OS for the first time! \033[0m\n"
  ____CLRF____

  ${sugo} $VENV_PATH/bin/python3 "$(pwd)/homedock.py"
}

____MAIN____
