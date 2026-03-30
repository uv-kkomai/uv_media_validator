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

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
