require 'exifr/jpeg'
require 'exifr/tiff'

module UvMediaValidator::Validator
  module ExifOrientation
    def width
      exif_rotated? ? image_size.h : image_size.w
    end

    def height
      exif_rotated? ? image_size.w : image_size.h
    end

    private

    def exif_rotated?
      return @exif_rotated if defined?(@exif_rotated)
      @exif_rotated = check_exif_rotated
    end

    def check_exif_rotated
      orientation = read_orientation
      [5, 6, 7, 8].include?(orientation)
    end

    def read_orientation
      case image_size.format
      when :jpeg
        EXIFR::JPEG.new(@path).orientation&.to_i
      when :tiff
        EXIFR::TIFF.new(@path).orientation&.to_i
      end
    rescue EXIFR::MalformedImage, IOError, SystemCallError
      nil
    end
  end
end
