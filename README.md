Sample specification:
Best to use with samples no longer than 40 sec, 44100 sample rate, 24 bit, stereo, wav.

Audio output:
Stereo, 44100 sample rate (this should be set before launching the application in system audio settings together with the audio device).

Notes:
Folder structure shouold suppose to stay as it is for the program to work. 
Important: If this folder is moved to another location, update the path of this folder in supercollider startup.scd with the new path (as described in installation step 5.)

Folder structure:
.
└── compos-mentis-5-0/
    ├── README.md
    ├── compos-mentis-5-0.scd
    ├── samples/
    │   ├── 1a.wav
    │   ├── 1b.wav
    │   └── ...
    └── presets/
        ├── base
        ├── blank
        └── ...

Installation guide:
1. if not already on your device, download and install SuperCollider 3.13.0 (https://supercollider.github.io/downloads)
2. download compos-mentis-5-0 as zip from github
3. unzip the file in a desired location on your device
4. open supercollider app, navigate to top menu, choose from 'File' dropdown menu 'Open startup file'
5. in finder navigate to the compos-mentis-5-0 directory, inside of it find the file called 'compos-mentis-5-0.scd', drag and drop this file in the supercollider editor and place it on top of the file, it should give you a path like "/Users/../compos-mentis-5-0/compos-mentis-5-0.scd", add '.load' to the end of this path so it looks like this "/Users/../compos-mentis/compos-mentis-5-0/compos-mentis-5-0.scd".load; make sure that there is no conflicting code under it (for the simplest option, just comment out the code bellow with /* code */)
6. press save file
7. close supercollider and reopen it
8. after a short loading time, the GUI should appear, that's all!




