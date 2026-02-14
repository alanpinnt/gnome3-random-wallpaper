#!/bin/bash
#
# background_changer.sh - GNOME3 Random Wallpaper Changer
#
# DESCRIPTION:
#   Randomly selects and sets wallpaper images from a specified directory.
#   Works with GNOME desktop environment and supports both desktop background
#   and lock screen/screensaver images. Automatically handles dark mode.
#
# REQUIREMENTS:
#   - GNOME desktop environment (uses gsettings)
#   - Bash 4.0+
#   - Images in supported formats: jpg, jpeg, png, bmp, gif, webp
#
# MODES:
#   cron   - Changes wallpaper once and exits (default)
#            Use this mode when running from cron or systemd timer
#
#   timed  - Runs continuously, changing wallpaper at specified intervals
#            Use this mode when running manually or as a background service
#
# USAGE:
#   ./background_changer.sh                     # Run once with defaults
#   ./background_changer.sh -m timed -t 5m      # Change every 5 minutes
#   ./background_changer.sh -d ~/Wallpapers     # Use a different directory
#   ./background_changer.sh --help              # Show all options
#
# COMMAND-LINE OPTIONS:
#   -d, --dir DIR        Wallpaper directory (overrides WALLPAPER_DIR below)
#   -m, --mode MODE      'cron' (run once) or 'timed' (continuous loop)
#   -t, --interval TIME  Interval for timed mode (e.g., 30, 5m, 10m)
#   -h, --help           Show help message
#
# CRON SETUP:
#   To change wallpaper every 30 minutes, add to crontab (crontab -e):
#     */30 * * * * /path/to/background_changer.sh
#
#   Note: The script automatically handles DBUS session detection for cron.
#
# SYSTEMD USER SERVICE (alternative to cron):
#   Create ~/.config/systemd/user/wallpaper.service:
#     [Unit]
#     Description=Wallpaper Changer
#
#     [Service]
#     ExecStart=/path/to/background_changer.sh -m timed -t 30m
#     Restart=always
#
#     [Install]
#     WantedBy=default.target
#
#   Then run: systemctl --user enable --now wallpaper.service
#

set -e

# ============================================================
# USER CONFIGURATION - Set your wallpaper folder here
# ============================================================
WALLPAPER_DIR="$HOME/Pictures"
# ============================================================

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

A GNOME3 random wallpaper changer that cycles through images in a directory.

OPTIONS:
    -d, --dir DIR          Directory containing wallpaper images (default: WALLPAPER_DIR variable)
    -m, --mode MODE        Mode: 'cron' (run once) or 'timed' (continuous loop) (default: cron)
    -t, --interval TIME    Time interval for timed mode (e.g., 30, 5m) (default: 30)
    -h, --help             Show this help message

EXAMPLES:
    $0 --dir ~/Pictures --mode timed --interval 2m
    $0 -d /home/user/wallpapers -m cron

ENVIRONMENT VARIABLES:
    WALLPAPER_DIR         Override default wallpaper directory
    MODE                  Override default mode (cron/timed)
    TIME_INTERVAL         Override default time interval

EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--dir)
            DIR="$2"
            shift 2
            ;;
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -t|--interval)
            TIME_INTERVAL="$2"
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >&2
}

die() {
    log "ERROR: $1"
    exit 1
}

parse_time_interval() {
    local interval="$1"
    if [[ $interval =~ ^[0-9]+m$ ]]; then
        echo $((${interval%m} * 60))
    elif [[ $interval =~ ^[0-9]+$ ]]; then
        echo "$interval"
    else
        die "Invalid time interval format: $interval"
    fi
}

DIR="${DIR:-$WALLPAPER_DIR}"
MODE="${MODE:-cron}"
TIME_INTERVAL="${TIME_INTERVAL:-30}"

[[ -d "$DIR" ]] || die "Directory does not exist: $DIR"

image_files=("$DIR"/*.{jpg,jpeg,png,bmp,gif,webp})
valid_images=()
for file in "${image_files[@]}"; do
    [[ -f "$file" ]] && valid_images+=("$file")
done

[[ ${#valid_images[@]} -eq 0 ]] && die "No image files found in: $DIR"

# Try to get DBUS session address if not already set
if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
    # First try the most common methods
    if [[ -n "$XDG_RUNTIME_DIR" && -S "$XDG_RUNTIME_DIR/bus" ]]; then
        export DBUS_SESSION_BUS_ADDRESS="unix:path=$XDG_RUNTIME_DIR/bus"
    elif [[ -f "$HOME/.dbus/session-bus/$(cat /var/lib/dbus/machine-id 2>/dev/null || echo unknown)-0" ]]; then
        export DBUS_SESSION_BUS_ADDRESS=$(cat "$HOME/.dbus/session-bus/$(cat /var/lib/dbus/machine-id 2>/dev/null || echo unknown)-0" 2>/dev/null | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2-)
    else
        # Fallback methods for cron environment
        for user_pid in $(pgrep --euid "$EUID" gnome-session 2>/dev/null); do
            dbus_addr=$(grep -z DBUS_SESSION_BUS_ADDRESS "/proc/$user_pid/environ" 2>/dev/null | cut -d= -f2-)
            if [[ -n "$dbus_addr" ]]; then
                export DBUS_SESSION_BUS_ADDRESS="$dbus_addr"
                break
            fi
        done
        
        # If still not found, try systemd user environment
        if [[ -z "$DBUS_SESSION_BUS_ADDRESS" ]]; then
            systemctl --user show-environment 2>/dev/null | grep DBUS_SESSION_BUS_ADDRESS | cut -d= -f2- | while read addr; do
                [[ -n "$addr" ]] && export DBUS_SESSION_BUS_ADDRESS="$addr"
            done
        fi
    fi
fi

# Validate DBUS address
[[ -n "$DBUS_SESSION_BUS_ADDRESS" ]] || die "Could not get DBUS session address"

log "Starting wallpaper changer - Mode: $MODE, Directory: $DIR, Images found: ${#valid_images[@]}"

if [[ "$MODE" == "timed" ]]; then
    SLEEP_TIME=$(parse_time_interval "$TIME_INTERVAL")
    log "Time interval: ${SLEEP_TIME}s"
fi

while true; do
    PIC="${valid_images[RANDOM % ${#valid_images[@]}]}"
    log "Setting wallpaper: $(basename "$PIC")"
    
    # Test gsettings connectivity first
    if ! gsettings list-schemas >/dev/null 2>&1; then
        log "WARNING: gsettings not accessible, skipping wallpaper change"
        continue
    fi
    
    # Set wallpaper for both light and dark modes
    log "Setting wallpaper: gsettings set org.gnome.desktop.background picture-uri \"file://$PIC\""
    log "Setting screensaver: gsettings set org.gnome.desktop.screensaver picture-uri \"file://$PIC\""
    
    # Always set the standard picture-uri
    if gsettings set org.gnome.desktop.background picture-uri "file://$PIC" 2>/dev/null &&
       gsettings set org.gnome.desktop.screensaver picture-uri "file://$PIC" 2>/dev/null; then
        log "Wallpaper updated successfully"
        
        # Try to set dark mode wallpaper if the key is supported
        if gsettings set org.gnome.desktop.background picture-uri-dark "file://$PIC" 2>/dev/null; then
            log "Dark mode wallpaper also updated"
        fi
    else
        log "WARNING: Failed to set wallpaper - check DBUS connection"
    fi
    
    [[ "$MODE" == "timed" ]] && sleep "$SLEEP_TIME" || break
done
