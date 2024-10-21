# Custom Content in QuakeJS

Written by [digidigital](https://github.com/digidigital/)

The repak.js-script seems to no longer work with current versions of node.
You can add custom content (for personal use only!) like textures, models, maps to the pak0.pk3 of the Q3A-Demo that is used to obtain the proprietary art assets. 

[Grabisoft](https://github.com/grabisoft) has made a great [video](https://www.youtube.com/watch?v=m57rMXASWms&feature=youtu.be) that I used as the foundation for this guide. *Spoiler: I think the step where the checksums are calculated is made easier in this guide* 

**As a prerequisite I assume you have installed a "vanilla" server of quakejs running as user "quake" as described in this
[tutorial](https://steamforge.net/wiki/index.php/How_to_setup_a_local_QuakeJS_server_under_Debian_9_or_Debian_10#The_Simpler_Method).
It is important that you have checked your server is running fine in the default configuration.
The server should be stopped while you make all the changes.**
 
## PK3 Files
In order to change a pk3 file you simply rename it to .zip and open it with you preffered ZIP-manager software. After you have copied, deleted or added files you simply close the file an rename the extension back to .pk3 

First
```
mv pak0.pk3 pak0.zip
```
Add or delete content with a ZIP-Manager then
```
mv pak0.zip pak0.pk3
```
## Sources for custom content and missing textures
The Q3A demo is missing some textures and models compared with the full version (e.g. there is no BFG10!).
Therefore you might run into issues with missing textures or models when you add custom maps.
In order to add those missing items you can take the files from freely available sources.

If you prepare hi-res textures you find a good pack here
[ioquake hi res textures](https://ioquake3.org/extras/replacement_content/)

Openarena is the free "clone" of Q3A. all proprietary content is replaced with a free version. 
Download the [openarena](http://openarena.ws/download.php?view.4) in ZIP format in order to get the BFG10 replacement files...

Since openarena still misses a lot of textures replacement packs have been created 
[OA Packs 1](https://download.tuxfamily.org/openarena/files/pk3/missingtextures/) 
[OA Packs 2](https://download.tuxfamily.org/openarena/files/pk3/q3a2oa/)

The good news is that the files usually have the same name as in Q3A and you can find them in the same folder structure in the PK3 files. So it's basically about identifying what you need and then copy the files from one PAK3 to the same location in the pak0.pk3 you use on your server.

**It's not a good idea to simply copy all (hi-res) textures - this will make the pak0.pk3 too large!**

There are severaly websites that host maps for Q3A. I like Ente's Padmaps - Padgarden is one of the rare maps that use the fly item ;) 
[World of Padman](https://worldofpadman.net/en/download/padfiles-q3a/)

## Adding content

If you want to add a model, skin or map just copy the files from the pk3 into the same folders in the pak0.pk3 as described above (Rename file extension to .zip -> copy files/folders -> paste in your .pk3 -> close files -> rename extension back to .pk3)

In order to keep the size low you might want to delete the original maps from the maps folder (.bsp & .aas) and replace the videos in the video folder with empty files with the same name.

## Preparing your server

In order for your server to accept the changes in pak0.pk3 you need to make some changes in some text files and copy your pak to the right places.

### .js-files

You need to remove the reference to pak0.pk3 in the following files 

```
sudo nano ~/quakejs/build/ioq3ded.js
```

```
sudo nano ~/quakejs/build/ioquake3.js
```

```
sudo nano /var/www/html/ioquake.js
```

Press "CTRL + w" and search for "linuxq3ademo"

Delete **exactly** this from the files:

*{name:"linuxq3ademo-1.11-6.x86.gz.sh",offset:5468,paks:[{src:"demoq3/pak0.pk3",dest:"baseq3/pak0.pk3",checksum:2483777038}]},*

Press "CTRL+o" to write the file and "CTRL+x" to exit nano.

### Copy pak0.pk3

Delete the old pak0 from the assets folder
```
sudo rm /var/www/html/assets/baseq3/*-pak0.pk3
```

Copy your pak0.pk3 in these folders
```
sudo cp /path/to/your/file/pak0.pk3 ~/quakejs/base/baseq3
sudo cp /path/to/your/file/pak0.pk3 /var/www/html/assets/baseq3
```

The file in the *web-server-folder* (**not the one in your home folder!!!**) needs to be renamed. You need the files CRC32 checksum as a prefix. This checksum needs to be added to the manifest.json in a later step as well.

**The result should look like this:**
12345678-pak0.pk3

### Creating the checksums

I have made two scripts that help you to calculate the checksum for pak-files (you need to know it in order to rename the files in your /var/www/html/assets/baseq3/ folder and to adjust the values in manifest.json)

*If are not sure which tool/shell command to execute take "crc-rename" -> Example: "Rename a single file" **after** you have copied pak0.pk3 in the webserver folder.* 

Both scripts need libarchive-zip-perl to calculate the checksum

```
sudo apt install libarchive-zip-perl
```
#### crc32info
Use this to get a list of CRC32 / filename values

In case the script ist not executable 
```
sudo chmod +x crc32info 
```

**Examples**

Get the crc32-info for one file
``` 
 ./crc32info /var/www/html/assets/baseq3/pak0.pk3
```

Calculate the crc32-info for all pk3-files in a directory
```
./crc32info /var/www/html/assets/baseq3/*pk3
```
#### crc32-rename
Use this to batch rename pk3-files. I just added sudo in front of the command in case you are not root ;)

In case the script ist not executable 

```
sudo chmod +x crc-rename
```

In case you do not have bash installed...
``` shell
sudo apt install bash
```

**Examples**

Rename a single file 
```
sudo ./crc-rename /var/www/html/assets/baseq3/pak0.pk3
```
Rename more than one file 
```
sudo ./crc-rename filename1 filename2 ...
```

Rename all pk3's in other directories
```
sudo ./crc-rename /var/www/html/assets/base*/*
```

### manifest.json

Open manifest.json and add yor pak0.pk3's information

```
sudo nano /var/www/html/asssets/manifest.json
```

After the info for pak101.pk3 add (**replace file size and checksum with the values for your file!!!**)
"Compressed" is the size in bytes. It seems it doesn't really matter if this value is not correct. Please note that the filename in the manifest does **not** contain the checksum.

```
  {
    "name": "baseq3/pak0.pk3",
    "compressed": 74500000,
    "checksum": 1638991753
  },
```

Press "CTRL+o" to write the file and "CTRL+x" to exit nano.

## Final steps

* Restart your webserver
```
sudo service apache2 restart
```

* Start your quakejs-Server

## Common issues / fixes
If the server starts fine but you can't connect or the games does not load you should check if you have followed all the steps from this tutorial. 

Things I ran into:
* My pak0.pk3 was too large (>~75MB)
* I did not restart the webserver and for some reason this caused issues
* My browser did not have the latest content (clear browser cache and saved data)
* Typos while renaming files or adjusting the manifest.json
* Forgot to adjust the values in manifest.json
* I deleted files from pak0.pk3 that were needed to start the game
* Forgot to put the updated pak0.pk3 in both folders 
 
## How to find what is missing...

### Textures
When you put custom maps in the pak0.pk3 you may run into the issue that you have a lot of missing textures.

This issue can be solved by manually adding the missing textures. If you use the demo pak0.pk3 you can take the CC-licensed hi-res textures from [here](https://ioquake3.org/extras/replacement_content/) or in case there is still something missing from openarena. The openarena-zip contains a pak4-textures.pk3

In order to find out what is missing start the map in your browser and open the console by pressing

SHIFT+^ or ~

then type

/shaderlist

now write down all textures that are commented with "DEFAULTED".
Those are the files you need to find and put in the texture folders of pak0.pk3

If the map uses a lot of textures/shaders the upper part of the list sometimes is not displayed in the console. In this case you can open the page in Firefox developer mode (Press F12). Switch to the Console-Tab. Everything in the game's console is displayed there as well.

### BFG10

You need the files from opeanarenas pak0.pk3 ("*" means all files from that folder)
* /models/powerups/ammo/bfgam.md3
* /models/powerups/ammo/bfgammo2.tga
* /models/weaphits/bfgboom/*
* /models/weaphits/bfg.md3
* /models/weaphits/bfg.tga
* /models/weaphits/bfg01.jpg
* /models/weaphits/bfg02.jpg
* /models/weaphits/bfg03.jpg
* /models/weaphits/bfg2.tga
* /models/weaphits/bfg3.tga
* /models/weaphits/bfgscroll.tga
* /models/weaphits/fbfg.md3
* /models/weapons2/bfg/*
