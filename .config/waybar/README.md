__In case Waybar is invisible__

The likely -and only- cause is the output setting in ``config.json``. Make sure the output property is set to the monitor you want Waybar to be displayed on. If you only use one monitor, simply remove or comment the output line altogether.

__In case the scripts aren't loading__

You can check the files' permission status with the ```ls -l``` command or ```chmod``` them to any status you want.
