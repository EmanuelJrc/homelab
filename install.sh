#!/bin/bash
set -e

LOGFILE="/var/log/htpc-installer.log"
exec > >(tee -a "$LOGFILE") 2>&1

BOOT_DRIVE="/dev/sda"
MEDIA_MOUNT="/share_media"
DOCKER_ROOT="/docker"
ENV_FILE="$DOCKER_ROOT/.env"

# ---------- Helpers ----------

require_root() {
  if [ "$EUID" -ne 0 ]; then
    whiptail --title "Permission error" --msgbox "Please run this script as root (sudo)." 10 60
    exit 1
  fi
}

check_whiptail() {
  if ! command -v whiptail >/dev/null 2>&1; then
    echo "whiptail not found, installing..."
    apt update && apt install -y whiptail
  fi
}

pause_msg() {
  whiptail --title "$1" --msgbox "$2" 12 70
}

error_msg() {
  whiptail --title "Error" --msgbox "$1\n\nSee log: $LOGFILE" 14 70
}

confirm() {
  whiptail --title "$1" --yesno "$2" 12 70
}

progress_step() {
  local PERCENT="$1"
  local MSG="$2"
  echo "XXX"
  echo "$PERCENT"
  echo "$MSG"
  echo "XXX"
}

# ---------- Disk selection & mount ----------

select_media_disk() {
  local options=()
  while read -r line; do
    local name size type
    name=$(echo "$line" | awk '{print $1}')
    size=$(echo "$line" | awk '{print $2}')
    type=$(echo "$line" | awk '{print $3}')
    [ "$type" != "disk" ] && continue
    [ "$name" = "$BOOT_DRIVE" ] && continue
    options+=("$name" "$size")
  done < <(lsblk -dpno NAME,SIZE,TYPE)

  if [ ${#options[@]} -eq 0 ]; then
    error_msg "No non-boot disks found.\nBoot drive: $BOOT_DRIVE\nConnect a media disk and try again."
    exit 1
  fi

  MEDIA_DISK=$(whiptail --title "Select media disk" --menu "Choose disk to use for $MEDIA_MOUNT" 15 70 5 "${options[@]}" 3>&1 1>&2 2>&3) || {
    error_msg "Disk selection cancelled."
    exit 1
  }
}

format_media_disk() {
  if confirm "Format disk?" "Do you want to format $MEDIA_DISK as ext4?\n\nWARNING: This will erase all data on it."; then
    mkfs.ext4 -F "$MEDIA_DISK"
  fi
}

mount_media_disk() {
  mkdir -p "$MEDIA_MOUNT"
  mountpoint -q "$MEDIA_MOUNT" && umount "$MEDIA_MOUNT" || true
  mount "$MEDIA_DISK" "$MEDIA_MOUNT"

  local uuid
  uuid=$(blkid -s UUID -o value "$MEDIA_DISK")
  if ! grep -q "$uuid" /etc/fstab; then
    echo "UUID=$uuid $MEDIA_MOUNT ext4 defaults 0 2" >> /etc/fstab
  fi
}

create_media_folders() {
  mkdir -p "$MEDIA_MOUNT"/{tv,movies,anime,downloads,books,manga,comics}
  chown -R 1000:1000 "$MEDIA_MOUNT"
}

# ---------- Docker & env ----------

prepare_docker_dirs() {
  mkdir -p "$DOCKER_ROOT/appdata"
  sudo mkdir -p /docker/appdata/homepage
  sudo cp -r ./config/homepage/* /docker/appdata/homepage/
}

ensure_env_file() {
  if [ ! -f "$ENV_FILE" ]; then
    if confirm "Create .env?" "$ENV_FILE not found.\nCreate a basic one now?"; then
      cat > "$ENV_FILE" <<EOF
PUID=1000
PGID=1000
TZ=Europe/Zagreb

APPDATA=$DOCKER_ROOT/appdata
MEDIA_ROOT=$MEDIA_MOUNT
DOWNLOADS=$MEDIA_MOUNT/downloads

TV=$MEDIA_MOUNT/tv
MOVIES=$MEDIA_MOUNT/movies
ANIME=$MEDIA_MOUNT/anime
BOOKS=$MEDIA_MOUNT/books
MANGA=$MEDIA_MOUNT/manga
COMICS=$MEDIA_MOUNT/comics
EOF
    else
      error_msg "$ENV_FILE is required. Create it manually and rerun."
      exit 1
    fi
  fi

  if confirm "Review .env?" "Do you want to view the current $ENV_FILE?"; then
    whiptail --title ".env preview" --scrolltext --msgbox "$(cat "$ENV_FILE")" 20 80
  fi
}

install_docker() {
  if ! command -v docker >/dev/null 2>&1; then
    curl -fsSL https://get.docker.com | sh
  fi

  if ! id -nG "$SUDO_USER" 2>/dev/null | grep -qw "docker"; then
    usermod -aG docker "$SUDO_USER"
  fi

  apt-get update
  apt-get install -y docker-compose-plugin
}

create_dc_wrapper() {
  cat > /usr/local/bin/dc <<EOF
#!/bin/bash
docker compose --env-file $ENV_FILE "\$@"
EOF
  chmod +x /usr/local/bin/dc
}

create_htpc_network() {
  docker network create htpc || true
}

start_stacks() {
  local base_dir
  base_dir=$(pwd)

  for stack in media-stack downloads infrastructure monitoring; do
    if [ -d "$base_dir/$stack" ]; then
      cd "$base_dir/$stack"
      dc up -d || true
    fi
  done

  cd "$base_dir"
}

# ---------- Main flow ----------

require_root
check_whiptail

whiptail --title "HTPC Installer" --msgbox "This wizard will:\n\n- Select and mount a media disk to $MEDIA_MOUNT\n- Create media folders\n- Prepare Docker directories at $DOCKER_ROOT\n- Ensure $ENV_FILE exists\n- Install Docker & docker-compose plugin\n- Create 'dc' wrapper\n- Start your stacks\n\nPress OK to continue." 18 70

select_media_disk
format_media_disk

{
  progress_step 5  "Mounting media disk..."
  mount_media_disk

  progress_step 15 "Creating media folders..."
  create_media_folders

  progress_step 25 "Preparing Docker directories..."
  prepare_docker_dirs

  progress_step 35 "Ensuring .env file..."
  ensure_env_file

  progress_step 55 "Installing Docker & compose..."
  install_docker

  progress_step 70 "Creating dc wrapper..."
  create_dc_wrapper

  progress_step 80 "Creating Docker network..."
  create_htpc_network

  progress_step 95 "Starting stacks..."
  start_stacks

  progress_step 100 "Done."
} | whiptail --gauge "Installing HTPC stack..." 8 70 0

pause_msg "Installation complete" "Installation finished.\n\nMedia mounted at: $MEDIA_MOUNT\nDocker root: $DOCKER_ROOT\n\nLog out and log back in to apply docker group membership.\n\nLog file: $LOGFILE"
