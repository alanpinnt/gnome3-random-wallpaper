#!/bin/bash

set -e

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

A GNOME3 random wallpaper changer that cycles through images in a directory.

OPTIONS:
    -d, --dir DIR          Directory containing wallpaper images (default: ~/Pictures)
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

DIR="${WALLPAPER_DIR:-$HOME/Pictures}"
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
