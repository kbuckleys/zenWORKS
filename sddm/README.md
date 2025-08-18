To install the theme, copy the kripton folder to the sddm theme directory:

``sudo cp -d /path/of/folder/ /usr/share/sddm/themes/``

Edit the sddm config file to point it to your newly installed theme:

``sudo nano /etc/sddm.conf``

And then insert this snippet and save the file:

``[theme]
Current=kripton``

Restart the sddm service:

``sudo systemctl restart sddm.service``
