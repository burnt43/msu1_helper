class FileConvertor
  FFMPEG_BIN                      = '/usr/bin/ffmpeg'
  FFMPEG_SUFFIX_OPTIONS           = '2>&1'
  TARGET_LUFS                     = -19
  FFMPEG_LOUDNORM_DATA_LINE_REGEX = %r/^\[Parsed_loudnorm/

  def initialize(input_filename, options={})
    @input_filename    = input_filename

    @loop_start_sample_number = options[:loop_start_sample_number]
    @loop_end_sample_number   = options[:loop_end_sample_number]
    @destdir                  = options[:destdir]
    @no_clobber               = options[:no_clobber]
  end
  
  def convert_wav_to_msu1_pcm!
    puts '-'*90
    puts "\033[0;33m#{@input_filename}\033[0;0m"

    msu1_pcm_filename = "#{destdir}/#{Pathname.new(@input_filename).basename('.*')}.pcm"

    if @no_clobber && File.exist?(msu1_pcm_filename)
      print "file already exists and will not be overridden..."
      puts "\033[0;32mOK\033[0;0m"
    else  
      create_destdir!

      trimmed_filename    = trim_wav_file!(@input_filename)
      loudnorm_data       = analyze_loudnorm_of_wav_file(trimmed_filename)
      normalized_filename = normalize_wav_file!(trimmed_filename, loudnorm_data)

      final_wav_filename =
        if wav_file_upsampled?(trimmed_filename, normalized_filename)
          downsample_wav_file!(normalized_filename)
        else
          normalized_filename
        end

      raw_filename      = rawify_wav_file!(final_wav_filename)
      raw_file          = File.open(raw_filename, 'r')
      raw_file_contents = raw_file.read
      raw_file.close


      print "adding MSU-1 header..."
      File.open(msu1_pcm_filename, 'w') {|f|
        f.print('MSU1')
        f.print(loop_start_sample_number_little_endian_bytes.map(&:chr).join)
        f.print(raw_file_contents)
      }
      puts "\033[0;32mOK\033[0;0m"

      
      print "cleaning up temp files..."
      FileUtils.rm(trimmed_filename)
      FileUtils.rm(normalized_filename)
      FileUtils.rm(raw_filename)
      FileUtils.rm(final_wav_filename) if File.exist?(final_wav_filename)
      puts "\033[0;32mOK\033[0;0m"

      puts "#{msu1_pcm_filename} created!"
    end
  end

  def convert_to_wav!
    puts '-'*90
    puts "\033[0;33m#{@input_filename}\033[0;0m"
    create_destdir!

    wav_filename     = wavify_file!(@input_filename)
    renamed_filename = rename_file!(wav_filename)

    puts "#{renamed_filename} created!"
  end

  private

  def rename_file!(input_filename)
    print "renaming file..."
    renamed_basename = Pathname.new(input_filename).basename('.*').to_s
      .downcase
      .gsub(/\s+/,'_')
      .gsub(/[,\.\-]/,'_')
      .gsub(/['?!()~]/,'')
      .sub(/^\d+/) {|digits| sprintf("%04d", digits.to_i)}
      .gsub(/_-_/,'_')
      .gsub(/_+/,'_')

    output_filename = "#{Pathname.new(input_filename).dirname}/#{renamed_basename}#{Pathname.new(input_filename).extname}"
    
    FileUtils.mv(input_filename, output_filename, force: true) unless input_filename == output_filename
    puts "\033[0;32mOK\033[0;0m"
    output_filename
  end

  def wavify_file!(input_filename)
    print "converting to wav..."
    output_filename = "#{destdir}/#{Pathname.new(input_filename).basename('.*')}.wav"

    execute_system_command!(%Q(#{FFMPEG_BIN} -y -i "#{input_filename}" -acodec pcm_s16le "#{output_filename}" #{FFMPEG_SUFFIX_OPTIONS}))
    puts "\033[0;32mOK\033[0;0m"
    output_filename
  end

  def trim_wav_file!(input_filename)
    print "trimming..."

    output_filename =
      "#{destdir}/#{Pathname.new(input_filename).basename('.*')}_" \
      "trimmed#{Pathname.new(input_filename).extname}"

    execute_system_command!(
      "#{FFMPEG_BIN} -y -i \"#{input_filename}\" " \
      "-af atrim=start_sample=0:end_sample=#{@loop_end_sample_number} " \
      "\"#{output_filename}\" #{FFMPEG_SUFFIX_OPTIONS}"
    )

    puts "\033[0;32mOK\033[0;0m"

    output_filename
  end

  def rawify_wav_file!(input_filename)
    print "converting to raw..."
    output_filename = "#{destdir}/#{Pathname.new(input_filename).basename('.*')}.raw"

    execute_system_command!(%Q(#{FFMPEG_BIN} -y -i "#{input_filename}" -f s16le -c:a pcm_s16le "#{output_filename}" #{FFMPEG_SUFFIX_OPTIONS}))
    puts "\033[0;32mOK\033[0;0m"
    output_filename
  end

  def analyze_loudnorm_of_wav_file(input_filename)
    print "analyzing loudnorm..."

    ffmpeg_output =
      execute_system_command!(
        "#{FFMPEG_BIN} -i \"#{input_filename}\" " \
        "-af loudnorm=print_format=json " \
        "-f null - #{FFMPEG_SUFFIX_OPTIONS}"
      )

    puts "\033[0;32mOK\033[0;0m"

    print "parsing loudnorm data..."
    state       = :looking_for_json
    json_string = StringIO.new

    ffmpeg_output.each_line {|line|
      _line = line.strip
      if state == :looking_for_json && FFMPEG_LOUDNORM_DATA_LINE_REGEX.match(_line)
        state = :json_found
      elsif state == :json_found
        json_string.print _line
      end
    }

    json = JSON.parse(json_string.string)
    puts "\033[0;32mOK\033[0;0m"
    json
  end

  def normalize_wav_file!(input_filename, loudnorm_data)
    print "normalizing..."

    output_filename =
      "#{destdir}/#{Pathname.new(input_filename).basename('.*')}_" \
      "normalized#{Pathname.new(input_filename).extname}"

    execute_system_command!(
      "#{FFMPEG_BIN} -i \"#{input_filename}\" " \
      "-af loudnorm=linear=true:" \
      "I=#{TARGET_LUFS}:" \
      "measured_I=#{loudnorm_data['input_i']}:" \
      "measured_TP=#{loudnorm_data['input_tp']}:" \
      "measured_LRA=#{loudnorm_data['input_lra']}:" \
      "measured_thresh=#{loudnorm_data['input_thresh']}:" \
      "offset=#{loudnorm_data['target_offset']}:" \
      "print_format=json " \
      "\"#{output_filename}\" " \
      "#{FFMPEG_SUFFIX_OPTIONS}"
    )

    puts "\033[0;32mOK\033[0;0m"

    output_filename
  end

  def downsample_wav_file!(input_filename)
    print "downsampling..."

    output_filename =
      "#{destdir}/#{Pathname.new(input_filename).basename('.*')}_" \
      "downsampled#{Pathname.new(input_filename).extname}"

    execute_system_command!(
      "#{FFMPEG_BIN} -i \"#{input_filename}\" " \
      "-ar 44100 " \
      "\"#{output_filename}\" " \
      "#{FFMPEG_SUFFIX_OPTIONS}"
    )
      
    puts "\033[0;32mOK\033[0;0m"

    output_filename
  end

  # NOTE: I don't know how to query the sample rate with ffmpeg
  # so I am just going to use this cheap method of comparing the
  # file sizes.
  def wav_file_upsampled?(original_filename, compare_filename)
    Pathname.new(compare_filename).size > 2 * Pathname.new(original_filename).size
  end

  def execute_system_command!(string)
    #puts "\033[0;32m#{string}\033[0;0m"
    %x[#{string}]
  end

  def create_destdir!
    print "ensuring destdir exists..."
    FileUtils.mkdir_p(destdir)
    puts "\033[0;32mOK\033[0;0m"
  end

  def destdir
    @destdir || Pathname.new(@input_filename).dirname
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
