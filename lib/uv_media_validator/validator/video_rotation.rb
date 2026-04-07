module UvMediaValidator::Validator
  # 動画の回転情報および SAR (Sample Aspect Ratio) を考慮した
  # 表示寸法 (display dimensions) を算出するモジュール。
  module VideoRotation
    # SAR 適用済みの表示幅（ブラウザの videoWidth に対応）
    def width
      display_dimensions[0]
    end

    # SAR 適用済みの表示高さ（ブラウザの videoHeight に対応）
    def height
      display_dimensions[1]
    end

    private

    def display_dimensions
      return @display_dimensions if defined?(@display_dimensions)

      vs = video_stream_from_metadata
      coded_w, coded_h = coded_dimensions_from_metadata(vs)
      return @display_dimensions = [coded_w, coded_h] unless coded_w && coded_h

      sar_adjusted_w = apply_sar(coded_w, vs)

      # SAR は水平方向（幅）のみに適用される。
      # 90°/270° 回転後、元の coded_h が新しい幅、SAR 適用済みの幅が新しい高さになる。
      @display_dimensions = if swap_for_rotation?
                              [coded_h, sar_adjusted_w]
                            else
                              [sar_adjusted_w, coded_h]
                            end
    end

    # ffprobe のコード化寸法を metadata ストリームから取得する。
    # ストリームの width/height が両方揃わない場合は video_info にフォールバックする。
    #
    # 【重要な前提】streamio-ffmpeg (FFMPEG::Movie) は rotate タグが 90/270 の場合、
    # video_info.width と video_info.height を自動スワップして返す。
    # フォールバック時はこのスワップを逆転させて元のコード化寸法を復元する。
    def coded_dimensions_from_metadata(vs)
      swapped = rotation_tag_swaps?

      if vs && vs[:width] && vs[:height]
        [vs[:width], vs[:height]]
      elsif swapped
        [video_info.height, video_info.width]
      else
        [video_info.width, video_info.height]
      end
    end

    def apply_sar(coded_width, vs)
      return coded_width unless vs

      sar = vs[:sample_aspect_ratio]
      return coded_width unless sar.is_a?(String)

      parts = sar.split(':')
      return coded_width unless parts.size == 2

      sar_num = parts[0].to_i
      sar_den = parts[1].to_i
      return coded_width unless sar_den > 0 && sar_num > 0 && sar_num != sar_den

      (coded_width * Rational(sar_num, sar_den)).round
    end

    # rotate タグが 90/270 で streamio-ffmpeg が width/height をスワップ済みか判定
    def rotation_tag_swaps?
      rot = video_info.rotation
      rot && (rot.abs == 90 || rot.abs == 270)
    end

    # rotate タグまたは Display Matrix から回転による寸法スワップが必要か判定。
    # rotation が非 nil（0 を含む）の場合は rotate タグのみで判定し、side_data は参照しない。
    # rotation が nil の場合のみ side_data の Display Matrix を参照する。
    def swap_for_rotation?
      rotation_tag_swaps? || (!video_info.rotation && side_data_swaps_dimensions?)
    end

    def side_data_rotation
      return @side_data_rotation if defined?(@side_data_rotation)
      @side_data_rotation = read_side_data_rotation
    end

    def side_data_swaps_dimensions?
      r = side_data_rotation
      !r.nil? && r.abs != 0 && r.abs != 180
    end

    def video_stream_from_metadata
      return @video_stream_from_metadata if defined?(@video_stream_from_metadata)
      @video_stream_from_metadata = video_info.metadata[:streams]&.find { |s| s[:codec_type] == 'video' }
    end

    def read_side_data_rotation
      video_stream = video_stream_from_metadata
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
