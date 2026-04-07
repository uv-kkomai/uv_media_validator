require "bundler/setup"
require "uv_media_validator"

RSpec.shared_examples 'exif orientation support' do |klass|
  it 'returns rotated dimensions for JPEG with EXIF orientation 6' do
    media = klass.new('test/fixtures/800x418_exif_rotated.jpg')
    expect(media.width).to eq(418)
    expect(media.height).to eq(800)
  end

  it 'returns raw dimensions for JPEG without EXIF rotation' do
    media = klass.new('test/ig_images/800x418.jpg')
    expect(media.width).to eq(800)
    expect(media.height).to eq(418)
  end
end

RSpec.shared_context 'video_rotation_metadata' do
  let(:metadata_with_rotation) do
    {
      streams: [{
        codec_type: 'video',
        width: 1920, height: 1080,
        side_data_list: [{
          side_data_type: 'Display Matrix',
          rotation: -90
        }]
      }]
    }
  end

  let(:metadata_without_rotation) do
    {
      streams: [{
        codec_type: 'video',
        width: 1920, height: 1080
      }]
    }
  end

  let(:metadata_with_180_rotation) do
    {
      streams: [{
        codec_type: 'video',
        width: 1920, height: 1080,
        side_data_list: [{
          side_data_type: 'Display Matrix',
          rotation: 180
        }]
      }]
    }
  end

  let(:metadata_with_no_streams) do
    {}
  end

  let(:metadata_with_sar_no_rotation) do
    {
      streams: [{
        codec_type: 'video',
        width: 720, height: 480,
        sample_aspect_ratio: '32:27'
      }]
    }
  end

  let(:metadata_with_sar_and_rotation) do
    {
      streams: [{
        codec_type: 'video',
        width: 720, height: 480,
        sample_aspect_ratio: '32:27',
        side_data_list: [{
          side_data_type: 'Display Matrix',
          rotation: -90
        }]
      }]
    }
  end
end

RSpec.shared_examples 'video rotation support' do |klass|
  include_context 'video_rotation_metadata'

  it 'returns rotated dimensions when side_data_list has 90-degree rotation' do
    movie = double('FFMPEG::Movie',
      rotation: nil, width: 1920, height: 1080,
      size: 1000, metadata: metadata_with_rotation)
    media = klass.new('dummy.mp4', info: movie)
    expect(media.width).to eq(1080)
    expect(media.height).to eq(1920)
  end

  it 'returns raw dimensions when no side_data_list rotation' do
    movie = double('FFMPEG::Movie',
      rotation: nil, width: 1920, height: 1080,
      size: 1000, metadata: metadata_without_rotation)
    media = klass.new('dummy.mp4', info: movie)
    expect(media.width).to eq(1920)
    expect(media.height).to eq(1080)
  end

  it 'returns rotated dimensions based on coded size when tags[:rotate] is present' do
    # coded: 1920x1080, rotate=90 → streamio-ffmpeg returns width=1080,height=1920
    movie = double('FFMPEG::Movie',
      rotation: 90, width: 1080, height: 1920,
      size: 1000, metadata: metadata_with_rotation)
    media = klass.new('dummy.mp4', info: movie)
    expect(media.width).to eq(1080)
    expect(media.height).to eq(1920)
  end

  it 'does not swap dimensions for 180-degree side_data rotation' do
    movie = double('FFMPEG::Movie',
      rotation: nil, width: 1920, height: 1080,
      size: 1000, metadata: metadata_with_180_rotation)
    media = klass.new('dummy.mp4', info: movie)
    expect(media.width).to eq(1920)
    expect(media.height).to eq(1080)
  end

  it 'returns raw dimensions when metadata has no streams' do
    movie = double('FFMPEG::Movie',
      rotation: nil, width: 1920, height: 1080,
      size: 1000, metadata: metadata_with_no_streams)
    media = klass.new('dummy.mp4', info: movie)
    expect(media.width).to eq(1920)
    expect(media.height).to eq(1080)
  end

  it 'returns SAR-adjusted width when SAR is non-square (no rotation)' do
    movie = double('FFMPEG::Movie',
      rotation: nil, width: 720, height: 480,
      size: 1000, metadata: metadata_with_sar_no_rotation)
    media = klass.new('dummy.mp4', info: movie)
    # coded 720x480, SAR 32:27 → display 853x480
    expect(media.width).to eq(853)
    expect(media.height).to eq(480)
  end

  it 'returns rotated SAR-adjusted dimensions with SAR and rotation' do
    movie = double('FFMPEG::Movie',
      rotation: nil, width: 720, height: 480,
      size: 1000, metadata: metadata_with_sar_and_rotation)
    media = klass.new('dummy.mp4', info: movie)
    # coded 720x480, SAR 32:27 → 853x480 → rotated -90° → [480, 853]
    expect(media.width).to eq(480)
    expect(media.height).to eq(853)
  end
end

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
