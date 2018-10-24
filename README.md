# msu1_helper

### Usage
<pre>Usage: msu1_helper [options]
    -i, --input-files=INPUT_FILES    input file or glob
    -t, --output-type=OUTPUT_TYPE    type to convert audio to (wav_pcm_s16le, msu1_pcm)
    -s, --loop-start=LOOP_START      sample number of where the loop should start
    -e, --loop-end=LOOP_END          sample number of where the loop should end
    -l, --loop-table=LOOP_TABLE      loop table filename
    -d, --destdir=DESTDIR            write converted files to this directory
    -h, --help                       show this message</pre>

### High Level Explanation
If we have arbitrary audio files we want to use with the MSU-1 we need to do the following:

1. Convert the audio into wav signed 16-bit little endian 44.1kHz. This new audio file will have the the same raw audio data that the MSU-1 can read, but it will have a wav header. This is OK because we need to be able to open this audio file up in some program that can inspect audio
2. Use an audio program, preferably one that can show you sample numbers, to find the sample numbers of where you want the song to loop. Videogame songs, in general, loop seemlessly so you have to be able to find the sample numbers. Since the audio is 44.1kHz there will be 44,100 samples per second. You can think of each sample representing 1/44100th of a second of data. You need to find the sample number where loop will start and the sample number where the loop will end.
3. With the loop start and end points we cut all the audio from the wav file after the loop point. We can then remove the wav header and replace it with the MSU-1 header which contains the loop start point (in little endian).
### Bulk Conversion Example

#### starting with mp3 files
Suppose we start with a directory of mp3 files and we want to convert them for the MSU-1.
<pre>┌■ jcarson@burnt43 bar 
└% tree /home/jcarson/msu1_audio/foo/bar 
/home/jcarson/msu1_audio/foo/bar
└── mp3
    ├── 1 - Overworld Theme.mp3
    ├── 2 - Dungeon Theme.mp3
    └── 3 - Forest Theme.mp3

1 directory, 3 files</pre>

#### convert mp3 files to wav
We need to convert all these files to wav signed 16-bit little endian pcm. To do this we can run the following command:
<pre>┌■ jcarson@burnt43 msu1_helper git:master ●
└% ./msu1_helper.rb --input-files="/home/jcarson/msu1_audio/foo/bar/mp3/*.mp3" --output-type=wav_pcm_s16le --destdir="/home/jcarson/msu1_audio/foo/bar/wav"
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/mp3/0002_dungeon_theme.mp3 -acodec pcm_s16le /home/jcarson/msu1_audio/foo/bar/wav/0002_dungeon_theme.wav
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/mp3/0001_overworld_theme.mp3 -acodec pcm_s16le /home/jcarson/msu1_audio/foo/bar/wav/0001_overworld_theme.wav
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/mp3/0003_forest_theme.mp3 -acodec pcm_s16le /home/jcarson/msu1_audio/foo/bar/wav/0003_forest_theme.wav</pre>

We should now have the files in the mp3 directory renamed with a convention and now have converted files written into a wav directory
<pre>┌■ jcarson@burnt43 bar 
└% tree /home/jcarson/msu1_audio/foo/bar
/home/jcarson/msu1_audio/foo/bar
├── mp3
│   ├── 0001_overworld_theme.mp3
│   ├── 0002_dungeon_theme.mp3
│   └── 0003_forest_theme.mp3
└── wav
    ├── 0001_overworld_theme.wav
    ├── 0002_dungeon_theme.wav
    └── 0003_forest_theme.wav

2 directories, 6 files</pre>

#### use an audio editor/daw to find loop points
We can now open up the wav files in an audio editor or daw and find the sample numbers of where the loop should start and where the loop should end.

#### create loop table file
After finding the loop points we can create a loop table file that lists the files and the loop start and the loop end. It should look like the following:
<pre>0001_overworld_theme.wav,500_103, 2_340_100
0002_dungeon_theme.wav,140_346,1_567_890
0003_forest_theme.wav,0,44_100</pre>

The loop table maps files and their loop points

#### use loop table file to convert the wavs to something the MSU-1 can play
Now we can convert the wavs to pcm files that the MSU-1 can play. We can do that with the following command:
<pre>┌■ jcarson@burnt43 msu1_helper git:master ●
└% ./msu1_helper.rb --input-files="/home/jcarson/msu1_audio/foo/bar/wav/*.wav" --output-type=msu1_pcm --destdir="/home/jcarson/msu1_audio/foo/bar/pcm" --loop-table="/home/jcarson/msu1_audio/foo/bar/bar.lt"
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/wav/0001_overworld_theme.wav -af atrim=start_sample=0:end_sample=2340100 /home/jcarson/msu1_audio/foo/bar/pcm/0001_overworld_theme_trim.wav
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/pcm/0001_overworld_theme_trim.wav -f s16le -c:a pcm_s16le /home/jcarson/msu1_audio/foo/bar/pcm/0001_overworld_theme_trim.raw
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/wav/0003_forest_theme.wav -af atrim=start_sample=0:end_sample=44100 /home/jcarson/msu1_audio/foo/bar/pcm/0003_forest_theme_trim.wav
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/pcm/0003_forest_theme_trim.wav -f s16le -c:a pcm_s16le /home/jcarson/msu1_audio/foo/bar/pcm/0003_forest_theme_trim.raw
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/wav/0002_dungeon_theme.wav -af atrim=start_sample=0:end_sample=1567890 /home/jcarson/msu1_audio/foo/bar/pcm/0002_dungeon_theme_trim.wav
/usr/bin/ffmpeg -hide_banner -loglevel panic -y -i /home/jcarson/msu1_audio/foo/bar/pcm/0002_dungeon_theme_trim.wav -f s16le -c:a pcm_s16le /home/jcarson/msu1_audio/foo/bar/pcm/0002_dungeon_theme_trim.raw</pre>

We should now have a pcm directory with the files:
<pre>┌■ jcarson@burnt43 bar 
└% tree /home/jcarson/msu1_audio/foo/bar
/home/jcarson/msu1_audio/foo/bar
├── bar.lt
├── mp3
│   ├── 0001_overworld_theme.mp3
│   ├── 0002_dungeon_theme.mp3
│   └── 0003_forest_theme.mp3
├── pcm
│   ├── 0001_overworld_theme.pcm
│   ├── 0002_dungeon_theme.pcm
│   └── 0003_forest_theme.pcm
└── wav
    ├── 0001_overworld_theme.wav
    ├── 0002_dungeon_theme.wav
    └── 0003_forest_theme.wav

3 directories, 10 files</pre>
