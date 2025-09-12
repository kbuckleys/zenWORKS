__Note:__ For some reason, I have to manually tell xdg-open to use nvim as my default editor system-wide. Should you face a similar issue with launchers like rofi or dmenu, this is the solution. However, you don't need to follow any of the steps if you'll be using ```mimeapps.list``` in my ```.config``` folder.

All you have to do is place ```nvim.desktop``` in its designated location as shown here, and update xdg-mime using this command:

```xdg-mime default nvim.desktop text/plain```

You may also need to review the file itself if you use a terminal orther than kitty.
