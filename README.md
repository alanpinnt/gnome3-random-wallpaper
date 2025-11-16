# gnome3-random-wallpaper

Simple wallpaper and lock screen changer. 
Works with Gnome 3 - tested on Ubuntu - up to 24.04 

## Features
- Automatically defaults to the current user's Pictures directory (`~/Pictures`)
- Two modes: cron (run once) or timed (continuous loop)
- Configurable time intervals for timed mode
- Command-line options for customization

## Future roadmap
- Testing on other linux operating systems

## Usage
```bash
./background_changer.sh [OPTIONS]

OPTIONS:
    -d, --dir DIR          Directory containing wallpaper images (default: ~/Pictures)
    -m, --mode MODE        Mode: 'cron' (run once) or 'timed' (continuous loop) (default: cron)
    -t, --interval TIME    Time interval for timed mode (e.g., 30, 5m) (default: 30)
    -h, --help             Show this help message

EXAMPLES:
    ./background_changer.sh --dir ~/Pictures --mode timed --interval 2m
    ./background_changer.sh -d /home/user/wallpapers -m cron
```

## Install instructions:
1. Clone or download the background_changer.sh file
2. Make it executable: `chmod +x background_changer.sh`
3. (Optional) Place your wallpaper images in `~/Pictures` or specify a different directory with `-d`
4. Run the script with your preferred mode and interval

The script now automatically uses the current user's Pictures directory, so no manual editing is required!

## Recent Changes

### Major Script Improvements
- **Added command-line argument parsing**: Script now accepts `-d/--dir`, `-m/--mode`, `-t/--interval`, and `-h/--help` options
- **Two operation modes**: 
  - `cron` mode: Run once and exit (ideal for cron jobs)
  - `timed` mode: Continuous loop with configurable intervals
- **Flexible time intervals**: Support for seconds (e.g., `30`) or minutes (e.g., `5m`)
- **Environment variable support**: `WALLPAPER_DIR`, `MODE`, and `TIME_INTERVAL` can be set via environment
- **Enhanced error handling**: Proper validation for directories, image files, and DBUS connectivity
- **Improved DBUS detection**: Multiple fallback methods to detect DBUS session address for cron environments
- **Better logging**: Timestamped log messages for debugging
- **Image format support**: Supports jpg, jpeg, png, bmp, gif, and webp formats
- **Dark mode support**: Automatically sets wallpaper for both light and dark themes when available
- **Robust file validation**: Checks for actual image files rather than just directory contents 
