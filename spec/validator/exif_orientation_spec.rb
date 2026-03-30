require 'spec_helper'

RSpec.describe UvMediaValidator::Validator::ExifOrientation do
  let(:test_class) do
    Class.new do
      include UvMediaValidator::Validator::ExifOrientation

      def initialize(path, format, w, h)
        @path = path
        @format = format
        @w = w
        @h = h
      end

      def image_size
        Struct.new(:format, :w, :h).new(@format, @w, @h)
      end
    end
  end

  describe 'orientation that swaps dimensions (5, 6, 7, 8)' do
    [5, 6, 7, 8].each do |orientation_value|
      context "orientation #{orientation_value}" do
        it 'swaps width and height' do
          media = test_class.new('dummy.jpg', :jpeg, 800, 418)
          allow(media).to receive(:read_orientation).and_return(orientation_value)
          expect(media.width).to eq(418)
          expect(media.height).to eq(800)
        end
      end
    end
  end

  describe 'orientation that does NOT swap dimensions (1, 2, 3, 4)' do
    [1, 2, 3, 4].each do |orientation_value|
      context "orientation #{orientation_value}" do
        it 'returns raw dimensions' do
          media = test_class.new('dummy.jpg', :jpeg, 800, 418)
          allow(media).to receive(:read_orientation).and_return(orientation_value)
          expect(media.width).to eq(800)
          expect(media.height).to eq(418)
        end
      end
    end
  end

  describe 'orientation nil (no EXIF data)' do
    it 'returns raw dimensions' do
      media = test_class.new('dummy.png', :png, 800, 418)
      allow(media).to receive(:read_orientation).and_return(nil)
      expect(media.width).to eq(800)
      expect(media.height).to eq(418)
    end
  end

  describe 'non-JPEG/TIFF format' do
    it 'returns raw dimensions for PNG' do
      media = test_class.new('dummy.png', :png, 800, 418)
      expect(media.width).to eq(800)
      expect(media.height).to eq(418)
    end

    it 'returns raw dimensions for GIF' do
      media = test_class.new('dummy.gif', :gif, 800, 418)
      expect(media.width).to eq(800)
      expect(media.height).to eq(418)
    end
  end
end
