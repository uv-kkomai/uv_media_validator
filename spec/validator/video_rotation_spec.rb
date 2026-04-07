require 'spec_helper'

RSpec.describe UvMediaValidator::Validator::VideoRotation do
  let(:test_class) do
    Class.new do
      prepend UvMediaValidator::Validator::VideoRotation

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

  # --- width / height: 回転のみ（SAR なし） ---

  describe 'width / height with rotation (no SAR)' do
    describe 'side_data with 90-degree rotation (rotation tag absent)' do
      [-90, 90, 270, -270].each do |angle|
        context "side_data rotation #{angle}" do
          it 'swaps width and height' do
            movie = build_movie(
              rotation: nil, width: 1920, height: 1080,
              metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080, side_data_list: [{ side_data_type: 'Display Matrix', rotation: angle }] }] }
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
          metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080, side_data_list: [{ side_data_type: 'Display Matrix', rotation: 180 }] }] }
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
          metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080, side_data_list: [{ side_data_type: 'Display Matrix', rotation: 0 }] }] }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end

    describe 'rotation tag = 0 with side_data 90-degree rotation' do
      it 'ignores side_data and does not swap (rotation tag takes precedence)' do
        movie = build_movie(
          rotation: 0, width: 1920, height: 1080,
          metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080, side_data_list: [{ side_data_type: 'Display Matrix', rotation: -90 }] }] }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end

    describe 'rotation tag present (streamio-ffmpeg already swapped)' do
      it 'un-swaps streamio rotation and re-swaps via coded dimensions' do
        movie = build_movie(
          rotation: 90, width: 1080, height: 1920,
          metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080, side_data_list: [{ side_data_type: 'Display Matrix', rotation: -90 }] }] }
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
          metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080 }] }
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
          metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080, side_data_list: [] }] }
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
          metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080, side_data_list: [{ side_data_type: 'Other Data' }] }] }
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
          metadata: { streams: [{ codec_type: 'video', width: 1920, height: 1080, side_data_list: 'invalid' }] }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end
  end

  # --- width / height: SAR 適用済み表示寸法 ---

  describe 'width / height with SAR (SAR-adjusted display dimensions)' do
    context 'SAR 16:9 with Display Matrix -180 (coded 1080x1920)' do
      it 'returns SAR-adjusted dimensions' do
        movie = build_movie(
          rotation: nil, width: 1080, height: 1920,
          metadata: {
            streams: [{
              codec_type: 'video', width: 1080, height: 1920,
              sample_aspect_ratio: '16:9',
              side_data_list: [{ side_data_type: 'Display Matrix', rotation: -180 }]
            }]
          }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1920)
      end
    end

    context 'SAR 16:9 without rotation (coded 1080x1920)' do
      it 'returns SAR-adjusted width' do
        movie = build_movie(
          rotation: nil, width: 1080, height: 1920,
          metadata: {
            streams: [{
              codec_type: 'video', width: 1080, height: 1920,
              sample_aspect_ratio: '16:9'
            }]
          }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1920)
      end
    end

    context 'SAR 16:9 with Display Matrix 90 (coded 1080x1920 → SAR 1920x1920 → rotated)' do
      it 'returns rotated SAR-adjusted dimensions' do
        movie = build_movie(
          rotation: nil, width: 1080, height: 1920,
          metadata: {
            streams: [{
              codec_type: 'video', width: 1080, height: 1920,
              sample_aspect_ratio: '16:9',
              side_data_list: [{ side_data_type: 'Display Matrix', rotation: 90 }]
            }]
          }
        )
        media = test_class.new(movie)
        # SAR-adjusted: 1920x1920 → rotated 90° → 1920x1920
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1920)
      end
    end

    context 'SAR 32:27 (NTSC DVD) with Display Matrix 90 (coded 720x480)' do
      it 'returns rotated SAR-adjusted dimensions' do
        movie = build_movie(
          rotation: nil, width: 720, height: 480,
          metadata: {
            streams: [{
              codec_type: 'video', width: 720, height: 480,
              sample_aspect_ratio: '32:27',
              side_data_list: [{ side_data_type: 'Display Matrix', rotation: 90 }]
            }]
          }
        )
        media = test_class.new(movie)
        # SAR-adjusted: 720*32/27=853 x 480 → rotated 90° → 480 x 853
        expect(media.width).to eq(480)
        expect(media.height).to eq(853)
      end
    end

    context 'SAR 4:3 with Display Matrix 90 (coded 540x960)' do
      it 'returns rotated SAR-adjusted dimensions' do
        movie = build_movie(
          rotation: nil, width: 540, height: 960,
          metadata: {
            streams: [{
              codec_type: 'video', width: 540, height: 960,
              sample_aspect_ratio: '4:3',
              side_data_list: [{ side_data_type: 'Display Matrix', rotation: 90 }]
            }]
          }
        )
        media = test_class.new(movie)
        # SAR-adjusted: 540*4/3=720 x 960 → rotated 90° → [960, 720]
        expect(media.width).to eq(960)
        expect(media.height).to eq(720)
      end
    end

    context 'SAR 32:27 (NTSC DVD) with Display Matrix -90 (coded 720x480)' do
      it 'returns rotated SAR-adjusted dimensions' do
        movie = build_movie(
          rotation: nil, width: 720, height: 480,
          metadata: {
            streams: [{
              codec_type: 'video', width: 720, height: 480,
              sample_aspect_ratio: '32:27',
              side_data_list: [{ side_data_type: 'Display Matrix', rotation: -90 }]
            }]
          }
        )
        media = test_class.new(movie)
        # SAR-adjusted: 720*32/27=853 x 480 → rotated -90° → 480 x 853
        expect(media.width).to eq(480)
        expect(media.height).to eq(853)
      end
    end

    context 'SAR 4:3 with Display Matrix 270 (coded 540x960)' do
      it 'returns rotated SAR-adjusted dimensions' do
        movie = build_movie(
          rotation: nil, width: 540, height: 960,
          metadata: {
            streams: [{
              codec_type: 'video', width: 540, height: 960,
              sample_aspect_ratio: '4:3',
              side_data_list: [{ side_data_type: 'Display Matrix', rotation: 270 }]
            }]
          }
        )
        media = test_class.new(movie)
        # SAR-adjusted: 540*4/3=720 x 960 → rotated 270° → [960, 720]
        expect(media.width).to eq(960)
        expect(media.height).to eq(720)
      end
    end

    context 'SAR 4:3 with rotation tag 180 (no swap, SAR only)' do
      it 'returns SAR-adjusted dimensions without swap' do
        movie = build_movie(
          rotation: 180, width: 540, height: 960,
          metadata: {
            streams: [{
              codec_type: 'video', width: 540, height: 960,
              sample_aspect_ratio: '4:3'
            }]
          }
        )
        media = test_class.new(movie)
        # SAR-adjusted: 540*4/3=720 x 960, rotation 180° → no swap → [720, 960]
        expect(media.width).to eq(720)
        expect(media.height).to eq(960)
      end
    end

    context 'SAR 4:3 with rotate tag (coded 540x960, rotate=90)' do
      it 'returns rotated SAR-adjusted dimensions' do
        movie = build_movie(
          rotation: 90, width: 960, height: 540,
          metadata: {
            streams: [{
              codec_type: 'video', width: 540, height: 960,
              sample_aspect_ratio: '4:3',
              side_data_list: [{ side_data_type: 'Display Matrix', rotation: -90 }]
            }]
          }
        )
        media = test_class.new(movie)
        # coded 540x960, SAR 4:3 → 720x960 → rotated 90° → [960, 720]
        expect(media.width).to eq(960)
        expect(media.height).to eq(720)
      end
    end

    context 'SAR 1:1 (no adjustment needed)' do
      it 'returns dimensions unchanged' do
        movie = build_movie(
          rotation: nil, width: 1920, height: 1080,
          metadata: {
            streams: [{
              codec_type: 'video', width: 1920, height: 1080,
              sample_aspect_ratio: '1:1'
            }]
          }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end

    context 'SAR 0:1 (unknown/invalid)' do
      it 'returns dimensions unchanged' do
        movie = build_movie(
          rotation: nil, width: 1920, height: 1080,
          metadata: {
            streams: [{
              codec_type: 'video', width: 1920, height: 1080,
              sample_aspect_ratio: '0:1'
            }]
          }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end

    context 'SAR "N/A" from ffprobe' do
      it 'returns dimensions unchanged' do
        movie = build_movie(
          rotation: nil, width: 1920, height: 1080,
          metadata: {
            streams: [{
              codec_type: 'video', width: 1920, height: 1080,
              sample_aspect_ratio: 'N/A'
            }]
          }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end

    context 'SAR absent in metadata' do
      it 'returns dimensions unchanged' do
        movie = build_movie(
          rotation: nil, width: 1920, height: 1080,
          metadata: {
            streams: [{
              codec_type: 'video', width: 1920, height: 1080
            }]
          }
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end

    context 'no streams in metadata (fallback to video_info)' do
      it 'returns video_info dimensions' do
        movie = build_movie(
          rotation: nil, width: 1920, height: 1080,
          metadata: {}
        )
        media = test_class.new(movie)
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end

    context 'no streams in metadata with rotation tag (fallback path)' do
      it 'un-swap and re-swap cancel out when no metadata' do
        movie = build_movie(
          rotation: 90, width: 1920, height: 1080,
          metadata: {}
        )
        media = test_class.new(movie)
        # streamio already swapped for rotation, no SAR info available
        expect(media.width).to eq(1920)
        expect(media.height).to eq(1080)
      end
    end

    context 'video stream exists but width/height are nil with rotation tag' do
      it 'falls back to streamio dimensions with un-swap' do
        movie = build_movie(
          rotation: 90, width: 1080, height: 1920,
          metadata: {
            streams: [{
              codec_type: 'video',
              sample_aspect_ratio: '1:1'
            }]
          }
        )
        media = test_class.new(movie)
        # streamio returns width=1080,height=1920 (swapped for coded 1920x1080)
        # fallback un-swaps: coded_w=1920, coded_h=1080
        # swap_for_rotation? → true → display [1080, 1920]
        expect(media.width).to eq(1080)
        expect(media.height).to eq(1920)
      end
    end

    context 'video stream exists but width/height are nil with non-square SAR' do
      it 'returns nil without crashing' do
        movie = build_movie(
          rotation: nil, width: nil, height: nil,
          metadata: {
            streams: [{
              codec_type: 'video',
              sample_aspect_ratio: '4:3'
            }]
          }
        )
        media = test_class.new(movie)
        expect(media.width).to be_nil
        expect(media.height).to be_nil
      end
    end
  end
end
