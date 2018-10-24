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

### Bulk Conversion Example
Let's say I have a directory of mp3 files that I want to convert to msu1_pcm format.
<pre>┌■ jcarson@burnt43 msu1_helper git:master ●
└% ls  /home/jcarson/msu1_audio/n64/mystical_ninja_starring_goemon/mp3/*.mp3
/home/jcarson/msu1_audio/n64/mystical_ninja_starring_goemon/mp3/19_yamato.mp3  /home/jcarson/msu1_audio/n64/mystical_ninja_starring_goemon/mp3/21_heartbeat_bossa_nova.mp3</pre>
The first thing I need to do is to convert these mp3s to signed 16-bit little endian pcm with a wav extension. I can do this with the following command.
<pre>┌■ jcarson@burnt43 msu1_helper git:master ●
└% ./msu1_helper.rb --input-files="/home/jcarson/msu1_audio/n64/mystical_ninja_starring_goemon/mp3/*.mp3" --output-type=wav_pcm_s16le --destdir=/home/jcarson/msu1_audio/n64/mystical_ninja_starring_goemon/wav</pre>
The command will just call ffmpeg and convert the files and then move then into their own wav subdirectory. We can now open this files in an audio editing program. I use Audacity. We can then find the sample numbers of the start and end of our loop. We can then put that data into a loop table file.
This is just a simple CSV file that is '$BASE_FILENAME,$LOOP_START,$LOOP_END'. So for instance the loop table file for the 2 files I converted to wav would look like the following.
<pre>19_yamato.wav,100,2000
21_heartbeat_bossa_nova.wav,5000,100000</pre>
We can then feed this script the wav files and the loop table to complete the conversion with the following command.
<pre>┌■ jcarson@burnt43 msu1_helper git:master ●
└% ./msu1_helper.rb --input-files="/home/jcarson/msu1_audio/n64/mystical_ninja_starring_goemon/wav/*.wav" --output-type=msu1_pcm --loop-table=/home/jcarson/msu1_audio/n64/mystical_ninja_starring_goemon/goemon.lt --destdir=/home/jcarson/msu1_audio/n64/mystical_ninja_starring_goemon/pcm</pre>
This will remove everything in the wav file after the loop_end and it will convert the wav to raw pcm format and stick the MSU-1 header on with the loop_start in the header.

