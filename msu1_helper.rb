#!/usr/local/ruby/ruby-2.3.3/bin/ruby
require 'pathname'
require 'optparse'
require 'ostruct'
require 'fileutils'

class ArgumentParser
  OUTPUT_TYPES = %w(wav_pcm_s16le msu1_pcm)

  def self.parse(args)
    options = OpenStruct.new
    options.input_files = nil
    options.output_type = nil
    options.loop_start  = nil
    options.loop_end    = nil
    options.loop_table  = nil
    options.destdir     = nil

    option_parser = OptionParser.new {|opts|
      opts.on("-i", "--input-files=INPUT_FILES", "input file or glob") {|input|
        options.input_files = Dir[input]
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
        options.loop_table = File.exists?(loop_table_filename) ? LoopTable.new(loop_table_filename) : nil
      }

      opts.on("-d", "--destdir=DESTDIR", "write converted files to this directory") {|destdir|
        options.destdir = destdir
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
    unless options.input_files
      print_error("no input was given. please specify using -i or --input.")
    end

    unless options.output_type
      print_error("no output_type was given. please specify using -t or --output-type")
    end

    # no input files
    if options.input_files.empty?
      print_error("could not find any input files.")
    # 1 input file
    elsif options.input_files.length == 1
      if (options.loop_start.nil? || options.loop_end.nil?)
        print_error("you want to convert a single file to msu1_pcm, but have not given a LOOP START or LOOP END. please specify using -s or --loop-start and -e or --loop-end.")
      end
    # multiple input files
    else
      if options.output_type == 'msu1_pcm'
        if options.loop_table.nil?
          print_error("you want you convert many files to msu1_pcm, but you have not provided a loop_table file. please specift using -l or --loop-table")
        else
          options.input_files
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
        values     = line.strip.split(',')
        filename   = values[0]
        loop_start = values[1].to_i
        loop_end   = values[2].to_i

        @data[filename] = {
          loop_start: loop_start,
          loop_end:   loop_end,
        }
      }
    }
  end

  def has_filename?(filename)
    @data.has_key?(key_from_filename(filename))
  end

  def loop_bounds_by_filename(filename)
    @data[key_from_filename(filename)]
  end

  private

  def key_from_filename(filename)
    Pathname.new(filename).basename.to_s
  end
end # LoopTable

class FileConvertor
  FFMPEG_BIN = '/usr/bin/ffmpeg'

  def initialize(input_filename, options={})
    @input_filename    = input_filename

    @loop_start_sample_number = options[:loop_start_sample_number]
    @loop_end_sample_number   = options[:loop_end_sample_number]
    @destdir                  = options[:destdir]
  end
  
  def convert_wav_to_msu1_pcm!
    create_destdir

    trimmed_filename = trim_wav_file!(@input_filename)
    raw_filename     = rawify_wav_file!(trimmed_filename)
    
    raw_file          = File.open(raw_filename, 'r')
    raw_file_contents = raw_file.read
    raw_file.close

    File.open(msu1_pcm_filename, 'w') {|f|
      f.print('MSU1')
      f.print(loop_start_sample_number_little_endian_bytes.map(&:chr).join)
      f.print(raw_file_contents)
    }

    FileUtils.rm(trimmed_filename)
    FileUtils.rm(raw_filename)
  end

  def convert_to_wav!
    create_destdir

    wavify_file!(@input_filename)
  end

  private

  def msu1_pcm_filename
    output_filename = "#{destdir}/#{output_file_basename}.pcm"
    output_filename
  end
  
  def wavify_file!(input_filename)
    output_filename = "#{destdir}/#{output_file_basename}.wav"

    execute_system_command("#{FFMPEG_BIN} -y -i #{input_filename} -acodec pcm_s16le #{output_filename}")
    output_filename
  end

  def trim_wav_file!(input_filename)
    output_filename = "#{destdir}/#{output_file_basename}_trim#{input_file_ext}"

    execute_system_command("#{FFMPEG_BIN} -y -i #{input_filename} -af atrim=start_sample=0:end_sample=#{@loop_end_sample_number} #{output_filename}")
    output_filename
  end

  def rawify_wav_file!(input_filename)
    output_filename = "#{destdir}/#{output_file_basename}.raw"

    execute_system_command("#{FFMPEG_BIN} -y -i #{input_filename} -f s16le -c:a pcm_s16le #{output_filename}")
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

  def execute_system_command(string)
    puts "\033[0;32m#{string}\033[0;0m"
    %x[#{string}]
  end

  def destdir
    @destdir || Pathname.new(@input_filename).dirname
  end

  def create_destdir
    FileUtils.mkdir_p(destdir)
  end

  def input_file_ext
    Pathname.new(@input_filename).extname
  end

  def output_file_basename
    Pathname.new(@input_filename).basename('.*')
  end
end # FileConvertor

class Msu1Helper
  def initialize(options)
    @options = options
  end

  def execute!
    case @options.output_type
    when 'wav_pcm_s16le'
      @options.input_files.each {|filename|
        FileConvertor.new(filename,{
          destdir: @options.destdir,
        }).convert_to_wav!
      }
    when 'msu1_pcm'
      @options.input_files.each {|filename|
        if loop_bounds = @options.loop_table.loop_bounds_by_filename(filename)
          FileConvertor.new(filename,{
            loop_start_sample_number: loop_bounds[:loop_start],
            loop_end_sample_number:   loop_bounds[:loop_end],
            destdir:                  @options.destdir,
          }).convert_wav_to_msu1_pcm!
        end 
      }
    end
  end
end # Msu1Helper

options = ArgumentParser.parse(ARGV)
Msu1Helper.new(options).execute!
