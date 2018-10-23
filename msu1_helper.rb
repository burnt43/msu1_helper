#!/usr/local/ruby/ruby-2.3.3/bin/ruby
require 'pathname'
require 'optparse'
require 'ostruct'

class ArgumentParser
  OUTPUT_TYPES = %w(wav_pcm_s16le msu1pcm)

  def self.parse(args)
    options = OpenStruct.new
    options.input               = nil
    options.output_type         = nil
    options.loop_start          = nil
    options.loop_end            = nil
    options.loop_table_filename = nil

    option_parser = OptionParser.new {|opts|
      opts.on("-i", "--input=INPUT", "input file or glob") {|input|
        options.input = input
      }

      opts.on("-t", "--output-type=OUTPUT_TYPE", "type to convert audio to (#{OUTPUT_TYPES.join(', ')})") {|output_type|
        options.output_type = output_type
      }

      opts.on("-s", "--loop-start=LOOP_START", "sample number of where the loop should start") {|loop_start|
        options.loop_start = loop_start
      }

      opts.on("-e", "--loop-end=LOOP_END", "sample number of where the loop should end") {|loop_end|
        options.loop_end = loop_end
      }

      opts.on("-l", "--loop-table=LOOP_TABLE", "loop table filename") {|loop_table_filename|
        options.loop_table_filename = loop_table_filename
      }

      opts.on_tail("-h", "--help", "show this message") do
        puts opts
        exit
      end
    }

    option_parser.parse!(args)

    validate_options(options)
    options
  end

  private

  def self.validate_options(options)
    unless options.input
      print_error("no input was given. please specify using -i or --input.")
    end

    unless options.output_type
      print_error("no output_type was given. please specify using -t or --output-type")
    end

    files_to_operate_on = Dir[options.input]

    if files_to_operate_on.empty?
      print_error("could not find any input files.")
    end

    if files_to_operate_on.length == 1 && (options.loop_start.nil? || options.loop_end.nil?)
      print_error("you want to convert a single file to msu1pcm, but have not given a LOOP START or LOOP END. please specify using -s or --loop-start and -e or --loop-end.")
    end

    if files_to_operate_on.length > 1 && options.output_type == 'msu1pcm' && options.loop_table_filename.nil?
      print_error("you want you convert many files to msu1pcm, but you have not provided a loop_table file.")
    end
  end

  def self.print_error(error_message)
    puts "[\033[0;31mERROR\033[0;0m] - #{error_message}"
    exit 1
  end
end # ArgumentParser

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

  private
  
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
end # Msu1Helper

ArgumentParser.parse(ARGV)
=begin
Msu1Helper.new('/home/jcarson/msu1_audio/nes/10_track_10.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/11_track_11.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/12_track_12.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/13_track_13.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/14_track_14.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/15_track_15.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/16_track_16.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/1_track_1.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/2_track_2.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/3_track_3.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/4_track_4.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/5_track_5.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/6_track_6.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/7_track_7.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/8_track_8.mp3').convert_to_wav!
Msu1Helper.new('/home/jcarson/msu1_audio/nes/9_track_9.mp3').convert_to_wav!

Msu1Helper.new('/home/jcarson/msu1_audio/snes/ff6/103_Awakening.wav',{
  msu1_pcm_filename:         '/home/jcarson/msu1_audio/snes/ff6/alttp_msu.pcm',
  loop_start_sample_number:  846_099,
  loop_end_sample_number:    2_540_145,
}).convert_wav_to_msu1_pcm!
=end
