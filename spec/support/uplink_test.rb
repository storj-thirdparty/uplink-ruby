# frozen_string_literal: true

require 'uplink'
require 'securerandom'
require 'digest'
require 'net/http'

module UplinkTest
  ACCESS_STRING = ENV.fetch('UPLINK_0_ACCESS')
  SATELLITE_ADDRESS = ENV.fetch('UPLINK_0_SATELLITE_ADDR')
  API_KEY = ENV.fetch('UPLINK_0_APIKEY')
  PASSPHRASE = ENV.fetch('UPLINK_0_PASSPHRASE')

  AUTH_SERVICE_ADDRESS = 'auth.storjshare.io:7777'
  LINK_SHARING_ADDRESS = 'https://link.storjshare.io'
  KEY_PATH = 'foo/test.txt'

  def bucket_name
    @bucket_name ||= "bucket-#{SecureRandom.hex(8)}"
  end

  def bucket_name2
    @bucket_name2 ||= "bucket-#{SecureRandom.hex(8)}"
  end

  def cleanup(access_string)
    Uplink.parse_access(access_string) do |access|
      access.open_project do |project|
        buckets = []

        project.list_buckets do |it|
          while it.next?
            bucket = it.item
            buckets << bucket
          end
        end

        buckets.each { |bucket| project.delete_bucket_with_objects(bucket.name) }
      rescue Uplink::BucketNotFoundError
        nil
      end
    end
  end

  def upload_object_from_string(project, bucket_name, key_path, contents, chunk_size = 0, custom = {})
    project.upload_object(bucket_name, key_path) do |upload|
      file_size = contents.size
      uploaded_total = 0

      while uploaded_total < file_size
        upload_size_left = file_size - uploaded_total
        len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

        bytes_written = upload.write(contents[uploaded_total, len], len)
        uploaded_total += bytes_written
      end

      upload.set_custom_metadata(custom) if custom && !custom.empty?

      upload.commit
    end
  end

  def download_object_as_string(project, bucket_name, key_path, chunk_size = 1000)
    downloaded_data = []

    project.download_object(bucket_name, key_path) do |download|
      object = download.info
      file_size = object.content_length

      downloaded_total = 0

      loop do
        download_size_left = file_size - downloaded_total
        len = chunk_size <= 0 ? download_size_left : [chunk_size, download_size_left].min

        bytes_read, is_eof = download.read(downloaded_data, len)
        downloaded_total += bytes_read

        break if is_eof
      end
    end

    downloaded_data.pack('C*').force_encoding('UTF-8')
  end
end
