#!/usr/local/ruby/ruby-2.3.3/bin/ruby
require 'pathname'
require 'optparse'
require 'ostruct'

class ArgumentParser
  OUTPUT_TYPES = %w(wav_pcm_s16le msu1pcm)

  def self.parse(args)
    options = OpenStruct.new
    options.input       = nil
    options.output_type = nil
    options.loop_start  = nil
    options.loop_end    = nil
    options.loop_table  = nil

    option_parser = OptionParser.new {|opts|
      opts.on("-i", "--input=INPUT", "input file or glob") {|input|
        options.input = Dir[input]
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

      opts.on("-l", "--loop-table=LOOP_TABLE_FILENAME", "loop table filename") {|loop_table_filename|
        options.loop_table = File.exists?(loop_table_filename) ? LoopTable.new(loop_table_filename) : nil
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

    # no input files
    if options.input.empty?
      print_error("could not find any input files.")
    # 1 input file
    elsif options.input.length == 1
      if (options.loop_start.nil? || options.loop_end.nil?)
        print_error("you want to convert a single file to msu1pcm, but have not given a LOOP START or LOOP END. please specify using -s or --loop-start and -e or --loop-end.")
      end
    # multiple input files
    else
      if options.output_type == 'msu1pcm'
        if options.loop_table.nil?
          print_error("you want you convert many files to msu1pcm, but you have not provided a loop_table file. please specift using -l or --loop-table")
        else
          options.input
            .reject{|filename| options.loop_table.has_filename?(filename)}
            .each{|filename| print_warning("#{filename} is not in the loop table. it will be ignored and not be converted.")}
        end
      end
    end
  end

  def self.print_warning(warning_message)
    puts "[\033[0;33mWARNING\033[0;0m] - #{warning_message}"
  end

  def self.print_error(error_message)
    puts "[\033[0;31mERROR\033[0;0m] - #{error_message}"
    exit 1
  end
end # ArgumentParser

class LoopTable
  def initialize(filename)
    @data = Hash.new

    File.open(filename, 'r') {|f|
      f.each_line {|line|
        filename, loop_start, loop_end = line.split(',')
        @data[filename] = {
          loop_start: loop_start,
          loop_end:   loop_end,
        }
      }
    }
  end

  def has_filename?(filename)
    @data.has_key?(Pathname.new(filename).basename.to_s)
  end
end # LoopTable

class FileConvertor
  FFMPEG_BIN = '/usr/bin/ffmpeg'

  def initialize(input_filename, options={})
    @input_filename    = input_filename

    @loop_start_sample_number = options[:loop_start_sample_number]
    @loop_end_sample_number   = options[:loop_end_sample_number]
  end
  
  def convert_wav_to_msu1pcm!
    trimmed_filename = trim_wav_file!(@input_filename)
    raw_filename     = rawify_wav_file!(trimmed_filename)
    
    raw_file          = File.open(raw_filename, 'r')
    raw_file_contents = raw_file.read
    raw_file.close

    File.open(msu1pcm_filename, 'w') {|f|
      f.print('MSU1')
      f.print(loop_start_sample_number_little_endian_bytes.map(&:chr).join)
      f.print(raw_file_contents)
    }
  end

  def convert_to_wav!
    wavify_file!(@input_filename)
  end

  def msu1pcm_filename
    pathname        = Pathname.new(@input_filename)
    output_filename = "#{pathname.dirname}/#{pathname.basename('.*')}.pcm"

    output_filename
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
end # FileConvertor

class Msu1Helper
  def initialize(options)
    @options = options
  end

  def execute!
  end
end

options = ArgumentParser.parse(ARGV)
#puts Msu1Helper.new('/home/jcarson/msu1_audio/snes/ff6/103_Awakening.wav').msu1pcm_filename


=begin
Msu1Helper.new('/home/jcarson/msu1_audio/snes/ff6/103_Awakening.wav',{
  loop_start_sample_number:  846_099,
  loop_end_sample_number:    2_540_145,
}).convert_wav_to_msu1_pcm!
=end
