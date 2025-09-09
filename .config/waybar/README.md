__In case Waybar is invisible__

The likely -and only- cause is the output setting in ``config.json``. Make sure the output property is set to the display you want Waybar to be displayed. If you only have one monitor, simply remove the output line altogether.

__In case the scripts aren't loading__

You can check the files' permission status with the ```ls -l``` command or ```chmod``` them to any status you want.
