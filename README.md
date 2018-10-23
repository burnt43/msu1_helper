# msu1_helper

### steps

1. convert an mp3 or whatever to wav(pcm s16le)
```
Msu1Helper.new(mp3_filename).convert_to_wav!
```

2. open up in audacity or whatever program and mess around until you find good start and end loop points make sure to take note of the sample numbers

3. input those sample numbers into the and convert to the msu1 headered pcm file
```
Msu1Helper.new('/home/jcarson/msu1_audio/snes/ff6/103_Awakening.wav',{
  msu1_pcm_filename:         '/home/jcarson/msu1_audio/snes/ff6/alttp_msu.pcm',
  loop_start_sample_number:  846_099,
  loop_end_sample_number:    2_540_145,
}).convert_wav_to_msu1_pcm!
```
