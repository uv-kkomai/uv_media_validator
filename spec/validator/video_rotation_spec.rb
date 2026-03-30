require 'spec_helper'

RSpec.describe UvMediaValidator::Validator::VideoRotation do
  let(:test_class) do
    Class.new do
      include UvMediaValidator::Validator::VideoRotation

      def initialize(video_info)
        @video_info = video_info
      end

      def video_info
        @video_info
      end
    end
  end

  def build_movie(rotation:, width:, height:, metadata:)
    double('FFMPEG::Movie', rotation: rotation, width: width, height: height, metadata: metadata)
  end

  describe 'side_data with 90-degree rotation (rotation tag absent)' do
    [-90, 90, 270, -270].each do |angle|
      context "side_data rotation #{angle}" do
        it 'swaps width and height' do
          movie = build_movie(
            rotation: nil, width: 1920, height: 1080,
            metadata: { streams: [{ codec_type: 'video', side_data_list: [{ side_data_type: 'Display Matrix', rotation: angle }] }] }
          )
          media = test_class.new(movie)
          expect(media.width).to eq(1080)
          expect(media.height).to eq(1920)
        end
      end
    end
  end

  describe 'side_data with 180-degree rotation' do
    it 'does not swap dimensions' do
      movie = build_movie(
        rotation: nil, width: 1920, height: 1080,
        metadata: { streams: [{ codec_type: 'video', side_data_list: [{ side_data_type: 'Display Matrix', rotation: 180 }] }] }
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1920)
      expect(media.height).to eq(1080)
    end
  end

  describe 'side_data with 0-degree rotation' do
    it 'does not swap dimensions' do
      movie = build_movie(
        rotation: nil, width: 1920, height: 1080,
        metadata: { streams: [{ codec_type: 'video', side_data_list: [{ side_data_type: 'Display Matrix', rotation: 0 }] }] }
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1920)
      expect(media.height).to eq(1080)
    end
  end

  describe 'rotation tag present (streamio-ffmpeg already swapped)' do
    it 'returns video_info dimensions as-is' do
      movie = build_movie(
        rotation: 90, width: 1080, height: 1920,
        metadata: { streams: [{ codec_type: 'video', side_data_list: [{ side_data_type: 'Display Matrix', rotation: -90 }] }] }
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1080)
      expect(media.height).to eq(1920)
    end
  end

  describe 'no side_data_list in video stream' do
    it 'returns raw dimensions' do
      movie = build_movie(
        rotation: nil, width: 1920, height: 1080,
        metadata: { streams: [{ codec_type: 'video' }] }
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1920)
      expect(media.height).to eq(1080)
    end
  end

  describe 'empty side_data_list' do
    it 'returns raw dimensions' do
      movie = build_movie(
        rotation: nil, width: 1920, height: 1080,
        metadata: { streams: [{ codec_type: 'video', side_data_list: [] }] }
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1920)
      expect(media.height).to eq(1080)
    end
  end

  describe 'side_data_list without Display Matrix' do
    it 'returns raw dimensions' do
      movie = build_movie(
        rotation: nil, width: 1920, height: 1080,
        metadata: { streams: [{ codec_type: 'video', side_data_list: [{ side_data_type: 'Other Data' }] }] }
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1920)
      expect(media.height).to eq(1080)
    end
  end

  describe 'no streams in metadata' do
    it 'returns raw dimensions' do
      movie = build_movie(
        rotation: nil, width: 1920, height: 1080,
        metadata: {}
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1920)
      expect(media.height).to eq(1080)
    end
  end

  describe 'no video stream in streams' do
    it 'returns raw dimensions' do
      movie = build_movie(
        rotation: nil, width: 1920, height: 1080,
        metadata: { streams: [{ codec_type: 'audio' }] }
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1920)
      expect(media.height).to eq(1080)
    end
  end

  describe 'side_data_list is not an Array' do
    it 'returns raw dimensions' do
      movie = build_movie(
        rotation: nil, width: 1920, height: 1080,
        metadata: { streams: [{ codec_type: 'video', side_data_list: 'invalid' }] }
      )
      media = test_class.new(movie)
      expect(media.width).to eq(1920)
      expect(media.height).to eq(1080)
    end
  end
end
