#!/usr/local/ruby/ruby-2.3.3/bin/ruby
require 'pathname'

class Msu1Helper
  FFMPEG_BIN = '/usr/bin/ffmpeg'

  def initialize(input_filename, options={})
    @input_filename    = input_filename

    @msu1_pcm_filename        = options[:msu1_pcm_filename]
    @loop_start_sample_number = options[:loop_start_sample_number]
    @loop_end_sample_number   = options[:loop_end_sample_number]
  end
  
  def convert_wav_to_msu1_pcm!
    trimmed_filename = trim_wav_file!(@input_filename)
    raw_filename     = rawify_wav_file!(trimmed_filename)
    
    raw_file          = File.open(raw_filename, 'r')
    raw_file_contents = raw_file.read
    raw_file.close

    File.open(@msu1_pcm_filename, 'w') {|f|
      f.print('MSU1')
      f.print(loop_start_sample_number_little_endian_bytes.map(&:chr).join)
      f.print(raw_file_contents)
    }
  end

  def convert_to_wav!
    wavify_file!(@input_filename)
  end

  #private
  
  def wavify_file!(input_filename)
    pathname        = Pathname.new(@input_filename)
    output_filename = "#{pathname.dirname}/#{pathname.basename('.*')}.wav"

    %x[#{FFMPEG_BIN} -y -i #{input_filename} -acodec pcm_s16le #{output_filename}]
    output_filename
  end

  def trim_wav_file!(input_filename)
    pathname        = Pathname.new(@input_filename)
    output_filename = "#{pathname.dirname}/#{pathname.basename('.*')}_trim#{pathname.extname}"

    %x[#{FFMPEG_BIN} -y -i #{input_filename} -af atrim=start_sample=0:end_sample=#{@loop_end_sample_number} #{output_filename}]
    output_filename
  end

  def rawify_wav_file!(input_filename)
    pathname        = Pathname.new(@input_filename)
    output_filename = "#{pathname.dirname}/#{pathname.basename('.*')}.raw"

    %x[#{FFMPEG_BIN} -y -i #{input_filename} -f s16le -c:a pcm_s16le #{output_filename}]
    output_filename
  end

  def loop_start_sample_number_little_endian_bytes
    bit_string   = @loop_start_sample_number.to_s(2)
    lowest_index = -bit_string.length

    4.times.map {|i|
      low_index  = -8 * (i + 1)
      high_index = -1 - (8 * i)

      starting_position = low_index < lowest_index ? lowest_index : low_index
      ending_position   = high_index

      bit_string[starting_position..ending_position].to_i(2)
    }
  end
end

Msu1Helper.new('/home/jcarson/msu1_audio/snes/ff6/103_Awakening.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/snes/ff6/103_Awakening.wav',{
  msu1_pcm_filename:         '/home/jcarson/msu1_audio/snes/ff6/alttp_msu.pcm',
  loop_start_sample_number:  846_099,
  loop_end_sample_number:    2_540_145,
}).convert_wav_to_msu1_pcm!
