# gnome3-random-wallpaper

Simple wallpaper and lock screen changer. 
Works with Gnome 3 - tested on Ubuntu 18.04.

Install instructions:
1. Create background_changer.sh file in your preferred directory
2. Edit background_changer.sh and set your image directory for all your images used for your wallpapers
3. Set crontab -e to whatever change interval you'd like: */5 * * * * /home/user/background_changer.sh

And tada! Your wallpaper and lock screen will change every 5 minutes under the example or whatever interval you'd like. 
