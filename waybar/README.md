__In case Waybar is invisible__

The likely -and only- cause is the output setting in ``config.json``. Make sure the output property is set to the monitor you want Waybar to be displayed on. If you only use one monitor, simply remove or comment the output line altogether.

__In case the scripts aren't loading__

Scripts need to have their permission set per-device. Chmod the files to make them executable.
