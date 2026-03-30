module UvMediaValidator::Validator
  module VideoRotation
    def width
      if video_info.rotation.nil? && side_data_swaps_dimensions?
        video_info.height
      else
        video_info.width
      end
    end

    def height
      if video_info.rotation.nil? && side_data_swaps_dimensions?
        video_info.width
      else
        video_info.height
      end
    end

    private

    def side_data_rotation
      return @side_data_rotation if defined?(@side_data_rotation)
      @side_data_rotation = read_side_data_rotation
    end

    def side_data_swaps_dimensions?
      r = side_data_rotation
      !r.nil? && r.abs != 0 && r.abs != 180
    end

    def read_side_data_rotation
      video_stream = video_info.metadata[:streams]&.find { |s| s[:codec_type] == 'video' }
      return nil unless video_stream

      side_data = video_stream[:side_data_list]
      return nil unless side_data.is_a?(Array)

      display_matrix = side_data.find { |sd| sd[:side_data_type] == 'Display Matrix' }
      display_matrix&.dig(:rotation)&.to_i
    rescue NoMethodError, TypeError
      nil
    end
  end
end
