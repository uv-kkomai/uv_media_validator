# frozen_string_literal: true

# === SAR テストフィクスチャ仕様（ffprobe 出力に基づく） ===
# 4s_1000x1000.mp4: coded 1000x1000, SAR 1:1,  DAR 1:1,     display 1000x1000
# 4s_2000x1000.mp4: coded 2000x1000, SAR 1:1,  DAR 2:1,     display 2000x1000
# 4s_500x1002.mp4:  coded 500x1002,  SAR 1:1,  DAR 250:501, display 500x1002
# 4s_1800x900.mp4:  coded 1800x900,  SAR 8:9,  DAR 16:9,    display 1600x900
# 4s_1920x1920.mp4: coded 1920x1920, SAR 16:9, DAR 16:9,    display 3413x1920

# rubocop:disable Metrics/BlockLength
RSpec.describe 'Pinterest' do
  it 'has a version number' do
    expect(UvMediaValidator::VERSION).not_to be nil
  end

  it 'get_pin_validator' do
    media = UvMediaValidator.get_pin_validator('test/pin_videos/4s_1000x1000.mp4')
    expect(media.class.name).to eq('UvMediaValidator::PinVideo')
    expect(media.all?).to eq(true)

    media = UvMediaValidator.get_pin_validator('test/pin_images/9038x9900.jpg')
    expect(media.class.name).to eq('UvMediaValidator::PinImage')
    expect(media.all?).to eq(true)
  end

  it 'get_pin_validator rejects video with SAR-inflated width exceeding MAX_WIDTH' do
    # coded 1920x1920, SAR 16:9 → display 3413x1920 (exceeds MAX_WIDTH=1920)
    media = UvMediaValidator.get_pin_validator('test/pin_videos/4s_1920x1920.mp4')
    expect(media.class.name).to eq('UvMediaValidator::PinVideo')
    expect(media.all?).to eq(false)
  end

  it 'get_pin_validator (H264)' do
    media = UvMediaValidator.get_pin_validator('test/pin_videos/30m_1280x1024_h264.mp4')
    expect(media.class.name).to eq('UvMediaValidator::PinVideo')
    expect(media.all?).to eq(true)
  end

  it 'get_pin_validator (H265)' do
    media = UvMediaValidator.get_pin_validator('test/pin_videos/30m_1280x1024_h265.mp4')
    expect(media.class.name).to eq('UvMediaValidator::PinVideo')
    expect(media.all?).to eq(true)
  end

  it_behaves_like 'video rotation support', UvMediaValidator::PinVideo
  it_behaves_like 'exif orientation support', UvMediaValidator::PinImage

  it 'pin image big file size' do
    media = UvMediaValidator::PinImage.new('test/pin_images/9038x9900_20MbyteOver.jpg')
    expect(media.file_size?).to eq(false)
    expect(media.format?).to eq(true)
    expect(media.all?).to eq(false)
  end

  it 'pin image bad format' do
    media = UvMediaValidator::PinImage.new('test/pin_images/500x500.psd')
    expect(media.format?).to eq(false)
    expect(media.all?).to eq(false)
  end

  it 'pin image valid' do
    path = 'test/pin_images'
    ary = %w[500x500.bmp 9038x9900.jpeg 9038x9900.png 500x500.tiff 9038x9900.webp]
    ary.each do |f|
      media = UvMediaValidator::PinImage.new(File.join(path, f))
      expect(media.all?).to eq(true), "cause #{f}"
    end
  end

  it 'pin video wrong aspect_ratio (for 1.91 / 1.0) with SAR 1:1' do
    # coded & display 2000x1000, ratio=2.0 > MAX_ASPECT_RATIO=1.91
    media = UvMediaValidator::PinVideo.new('test/pin_videos/4s_2000x1000.mp4')
    expect(media.file_size?).to eq(true)
    expect(media.duration?).to eq(true)
    expect(media.aspect_ratio?).to eq(false)
    expect(media.format?).to eq(true)
    expect(media.all?).to eq(false)
  end

  it 'pin video wrong aspect_ratio (for 1.0 / 2.0) with SAR 1:1' do
    # coded & display 500x1002, ratio=0.499 < MIN_ASPECT_RATIO=0.5
    media = UvMediaValidator::PinVideo.new('test/pin_videos/4s_500x1002.mp4')
    expect(media.file_size?).to eq(true)
    expect(media.duration?).to eq(true)
    expect(media.aspect_ratio?).to eq(false)
    expect(media.format?).to eq(true)
    expect(media.all?).to eq(false)
  end

  it 'pin video with non-square SAR has correct display aspect_ratio' do
    # coded 1800x900, SAR 8:9 → display 1600x900, ratio=1.778 (within [0.5, 1.91])
    media = UvMediaValidator::PinVideo.new('test/pin_videos/4s_1800x900.mp4')
    expect(media.aspect_ratio?).to eq(true)
  end

  it 'pin video bad duration' do
    media = UvMediaValidator::PinVideo.new('test/pin_videos/901s_1280x1024.mp4')
    expect(media.file_size?).to eq(true)
    expect(media.duration?).to eq(false)
    expect(media.aspect_ratio?).to eq(true)
    expect(media.format?).to eq(true)
    expect(media.all?).to eq(false)
  end

  it 'pin video valid' do
    path = 'test/pin_videos'
    ary = %w[30s_1280x1024.mov 30s_1280x1024.m4v 4s_1280x1024.mp4]
    ary.each do |f|
      media = UvMediaValidator::PinVideo.new(File.join(path, f))
      expect(media.all?).to eq(true), "cause #{f}"
    end
  end
end
# rubocop:enable Metrics/BlockLength
