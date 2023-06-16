# frozen_string_literal: true

require 'uplink'
require 'securerandom'
require 'digest'
require 'net/http'

describe Uplink do
  access_string = ENV.fetch('UPLINK_0_ACCESS')
  satellite_address = ENV.fetch('UPLINK_0_SATELLITE_ADDR')
  api_key = ENV.fetch('UPLINK_0_APIKEY')
  passphrase = ENV.fetch('UPLINK_0_PASSPHRASE')

  auth_service_address = 'auth.storjshare.io:7777'
  link_sharing_address = 'https://link.storjshare.io'
  key_path = 'foo/test.txt'

  let(:bucket_name) { "bucket-#{SecureRandom.hex(8)}" }
  let(:bucket_name2) { "bucket-#{SecureRandom.hex(8)}" }

  def cleanup(access_string)
    described_class.parse_access(access_string) do |access|
      access.open_project do |project|
        buckets = []

        project.list_buckets do |it|
          while it.next?
            bucket = it.item
            buckets << bucket
          end
        end

        buckets.each { |bucket| project.delete_bucket_with_objects(bucket.name) }
      rescue described_class::BucketNotFoundError
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

  after do
    cleanup(access_string)
  end

  context '[Access Tests]' do
    it 'parsing an access string' do
      expect { described_class.parse_access(access_string) { |_access| nil } }.not_to raise_error
    end

    it 'requesting access with passphrase' do
      expect { described_class.request_access_with_passphrase(satellite_address, api_key, passphrase) { |_access| nil } }.not_to raise_error
    end

    it 'requesting access with passphrase and with config' do
      config = {
        user_agent: 'Test/1.0',
        dial_timeout_milliseconds: 10_000
      }
      expect { described_class.request_access_with_passphrase_and_config(config, satellite_address, api_key, passphrase) { |_access| nil } }.not_to raise_error

      config = {
        dial_timeout_milliseconds: 1
      }
      expect { described_class.request_access_with_passphrase_and_config(config, satellite_address, api_key, passphrase) { |_access| nil } }.to raise_error(described_class::InternalError)
    end

    it 'returning satellite address' do
      described_class.parse_access(access_string) do |access|
        address = access.satellite_address
        expect(address).to eq(satellite_address)
      end
    end

    it 'serializing access string' do
      described_class.parse_access(access_string) do |access|
        access_str = access.serialize
        expect(access_str).to eq(access_string)
      end
    end

    it 'sharing an access for any buckets' do
      described_class.parse_access(access_string) do |access|
        permission = { allow_upload: true }

        access.share(permission, nil) do |shared_access|
          shared_access.open_project do |project|
            expect { project.ensure_bucket(bucket_name) }.not_to raise_error
            expect { project.ensure_bucket(bucket_name2) }.not_to raise_error
          end
        end
      end
    end

    it 'sharing an access for a bucket' do
      described_class.parse_access(access_string) do |access|
        permission = { allow_upload: true }
        prefixes = [
          { bucket: bucket_name }
        ]

        access.share(permission, prefixes) do |shared_access|
          shared_access.open_project do |project|
            expect { project.ensure_bucket(bucket_name) }.not_to raise_error
            expect { project.ensure_bucket(SecureRandom.hex(8)) }.to raise_error(described_class::InternalError)
          end
        end
      end
    end

    it 'sharing an access for multiple buckets' do
      described_class.parse_access(access_string) do |access|
        permission = { allow_upload: true }
        prefixes = [
          { bucket: bucket_name },
          { bucket: bucket_name2 }
        ]

        access.share(permission, prefixes) do |shared_access|
          shared_access.open_project do |project|
            expect { project.ensure_bucket(bucket_name) }.not_to raise_error
            expect { project.ensure_bucket(bucket_name2) }.not_to raise_error
          end
        end
      end
    end

    it 'sharing an access for a bucket with object key prefix' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)
        end

        permission = { allow_upload: true }
        prefixes = [
          { bucket: bucket_name, prefix: 'foo/' }
        ]

        access.share(permission, prefixes) do |shared_access|
          shared_access.open_project do |project|
            expect { upload_object_from_string(project, bucket_name, 'foo/test.txt', 'hello world') }.not_to raise_error
            expect { upload_object_from_string(project, bucket_name, 'test.txt', 'hello world') }.to raise_error(described_class::InternalError)
            expect { upload_object_from_string(project, bucket_name, 'bar/test.txt', 'hello world') }.to raise_error(described_class::InternalError)
          end
        end
      end
    end

    it 'sharing an access for a bucket with not_before and not_after permissions set' do
      described_class.parse_access(access_string) do |access|
        not_before = Time.now + 2
        not_after = Time.now + 4
        permission = { allow_upload: true, not_before: not_before, not_after: not_after }
        prefixes = [
          { bucket: bucket_name }
        ]

        access.share(permission, prefixes) do |shared_access|
          shared_access.open_project do |project|
            expect { project.ensure_bucket(bucket_name) }.to raise_error(described_class::InternalError)
            sleep(2)
            expect { project.ensure_bucket(bucket_name) }.not_to raise_error
            sleep(3)
            expect { project.ensure_bucket(bucket_name) }.to raise_error(described_class::InternalError)
          end
        end
      end
    end

    it 'overriding encryption key' do
      described_class.parse_access(access_string) do |access|
        described_class.derive_encryption_key('my-password', '123', 3) do |encryption_key|
          expect { access.override_encryption_key(bucket_name, 'foo/', encryption_key) }.not_to raise_error
        end
      end
    end

    it 'registering an edge access' do
      described_class.parse_access(access_string) do |access|
        permission = { allow_download: true, allow_list: true }
        prefixes = [
          { bucket: bucket_name }
        ]

        access.share(permission, prefixes) do |shared_access|
          edge_credential = shared_access.edge_register_access({ auth_service_address: auth_service_address })
          expect(edge_credential.access_key_id).not_to be_empty
          expect(edge_credential.secret_key).not_to be_empty
          expect(edge_credential.endpoint).to eq('https://gateway.storjshare.io')
        end
      end
    end

    it 'creating a direct share url for an object' do
      described_class.parse_access(access_string) do |access|
        contents = 'hello world'
        access.open_project do |project|
          project.ensure_bucket(bucket_name)
          upload_object_from_string(project, bucket_name, key_path, contents)
        end

        permission = { allow_download: true }
        prefixes = [
          { bucket: bucket_name }
        ]

        access.share(permission, prefixes) do |shared_access|
          edge_credential = shared_access.edge_register_access({ auth_service_address: auth_service_address }, { is_public: true })
          share_url = edge_credential.join_share_url(link_sharing_address, bucket_name, key_path, { raw: true })
          downloaded_contents = Net::HTTP.get(URI.parse(share_url))
          expect(downloaded_contents).to eq(contents)
        end
      end
    end

    it 'creating a page share url for an object' do
      described_class.parse_access(access_string) do |access|
        contents = 'hello world'
        access.open_project do |project|
          project.ensure_bucket(bucket_name)
          upload_object_from_string(project, bucket_name, key_path, contents)
        end

        permission = { allow_download: true }
        prefixes = [
          { bucket: bucket_name }
        ]

        access.share(permission, prefixes) do |shared_access|
          edge_credential = shared_access.edge_register_access({ auth_service_address: auth_service_address }, { is_public: true })
          share_url = edge_credential.join_share_url(link_sharing_address, bucket_name, key_path, { raw: false })
          expect(share_url).to match("#{link_sharing_address}/s/[a-z].*/#{bucket_name}/#{key_path}")
        end
      end
    end

    it 'creating a page share url for a bucket' do
      described_class.parse_access(access_string) do |access|
        contents = 'hello world'
        access.open_project do |project|
          project.ensure_bucket(bucket_name)
          upload_object_from_string(project, bucket_name, key_path, contents)
        end

        permission = { allow_download: true, allow_list: true }
        prefixes = [
          { bucket: bucket_name }
        ]

        access.share(permission, prefixes) do |shared_access|
          edge_credential = shared_access.edge_register_access({ auth_service_address: auth_service_address }, { is_public: true })
          share_url = edge_credential.join_share_url(link_sharing_address, bucket_name, nil, { raw: false })
          expect(share_url).to match("#{link_sharing_address}/s/[a-z].*/#{bucket_name}")
        end
      end
    end
  end

  context '[Project Tests]' do
    it 'opening a project (and closing the project automatically)' do
      described_class.parse_access(access_string) do |access|
        expect { access.open_project { |_project| nil } }.not_to raise_error
      end
    end

    it 'closing a project manually' do
      described_class.parse_access(access_string) do |access|
        access.open_project(auto_close: false) do |project|
          expect { project.close }.not_to raise_error
        end
      end
    end

    it 'opening a project with config' do
      described_class.parse_access(access_string) do |access|
        config = {
          user_agent: 'Test/1.0',
          dial_timeout_milliseconds: 10_000
        }
        expect { access.open_project_with_config(config) { |_project| nil } }.not_to raise_error

        config = {
          dial_timeout_milliseconds: 1
        }
        access.open_project_with_config(config) do |project|
          expect { project.ensure_bucket(bucket_name) }.to raise_error(described_class::InternalError)
        end
      end
    end

    it 'revoking a shared access' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          permission = { allow_upload: true, allow_delete: true, allow_download: true, allow_list: true }

          access.share(permission, nil) do |shared_access|
            shared_access.open_project do |shared_project|
              shared_project.ensure_bucket(bucket_name)
              expect { upload_object_from_string(shared_project, bucket_name, key_path, 'a') }.not_to raise_error
            end

            project.revoke_access(shared_access)

            success = false

            # revoke access sometimes could take a few seconds to take effect so use a retry strategy on the test
            10.times do
              shared_access.open_project do |shared_project|
                # this should raise InternalError with permission denied message if the revoke access has taken effect
                upload_object_from_string(shared_project, bucket_name, 'foo/test2.txt', 'a')
              end
            rescue described_class::TooManyRequestError
              sleep(1)
            rescue described_class::InternalError => e
              expect(e.message.include?('permission denied')).to be(true)
              success = true
              break
            end

            raise 'Test failed!' unless success
          end
        end
      end
    end
  end

  context '[Bucket Tests]' do
    it 'creating a new bucket' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          time = Time.now.to_i
          bucket = project.create_bucket(bucket_name)
          expect(bucket.name).to eq(bucket_name)
          expect(bucket.created).to be >= time
        end
      end
    end

    it 'raises error if creating a bucket with name that already exists' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.create_bucket(bucket_name)

          expect { project.create_bucket(bucket_name) }.to raise_error(described_class::BucketAlreadyExistsError)
        end
      end
    end

    it "ensuring a bucket (creating a new bucket if doesn't exist but doesn't raise error if bucket already exists)" do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          time = Time.now.to_i
          bucket = project.ensure_bucket(bucket_name)
          expect(bucket.name).to eq(bucket_name)
          expect(bucket.created).to be >= time
          bucket_created_time = bucket.created

          bucket = project.ensure_bucket(bucket_name)
          expect(bucket.name).to eq(bucket_name)
          expect(bucket.created).to eq(bucket_created_time)
        end
      end
    end

    it 'getting a stat of a bucket' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          time = Time.now.to_i
          project.ensure_bucket(bucket_name)

          bucket = project.stat_bucket(bucket_name)
          expect(bucket.name).to eq(bucket_name)
          expect(bucket.created).to be >= time
        end
      end
    end

    it "raises error if getting a stat of a bucket that doesn't exist" do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          expect { project.stat_bucket(SecureRandom.hex(8)) }.to raise_error(described_class::BucketNotFoundError)
        end
      end
    end

    it 'iterating buckets in a project' do
      cleanup(access_string)

      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          time = Time.now.to_i
          bucket_names = 3.times.map do
            bucket_name = "bucket-#{SecureRandom.hex(8)}"
            project.ensure_bucket(bucket_name)
            bucket_name
          end

          buckets = []

          project.list_buckets do |it|
            while it.next?
              bucket = it.item
              buckets << bucket
            end
          end

          expect(buckets.size).to eq(bucket_names.size)
          expect(buckets.map(&:name)).to match_array(bucket_names)
          buckets.each do |bucket|
            expect(bucket.created).to be >= time
          end
        end
      end
    end

    it 'iterating buckets in a project with cursor' do
      cleanup(access_string)

      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          3.times do
            project.ensure_bucket("bucket-#{SecureRandom.hex(8)}")
          end

          bucket_names = []

          # collect the bucket names first
          project.list_buckets do |it|
            while it.next?
              bucket = it.item
              bucket_names << bucket.name
            end
          end

          # the iterating would start from after second bucket
          cursor = bucket_names[1]

          expected_bucket_names = bucket_names[2...]

          buckets = []

          project.list_buckets({ cursor: cursor }) do |it|
            while it.next?
              bucket = it.item
              buckets << bucket
            end
          end

          expect(buckets.size).to eq(expected_bucket_names.size)
          expect(buckets.map(&:name)).to match_array(expected_bucket_names)
        end
      end
    end

    it 'deleting a bucket' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          project.delete_bucket(bucket_name)

          expect { project.stat_bucket(bucket_name) }.to raise_error(described_class::BucketNotFoundError)
        end
      end
    end

    it 'deleting a bucket with objects' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)
          upload_object_from_string(project, bucket_name, key_path, 'hello world')

          project.delete_bucket_with_objects(bucket_name)

          expect { project.stat_object(bucket_name, key_path) }.to raise_error(described_class::ObjectKeyNotFoundError)
          expect { project.stat_bucket(bucket_name) }.to raise_error(described_class::BucketNotFoundError)
        end
      end
    end

    it "raises error if deleting a bucket that doesn't exist" do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          expect { project.delete_bucket(SecureRandom.hex(8)) }.to raise_error(described_class::BucketNotFoundError)
          expect { project.delete_bucket_with_objects(SecureRandom.hex(8)) }.to raise_error(described_class::BucketNotFoundError)
        end
      end
    end
  end

  context '[Object Tests]' do
    it 'uploading an object to a bucket' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          time = Time.now.to_i

          contents = 'hello world'

          project.upload_object(bucket_name, key_path) do |upload|
            chunk_size = 1000

            file_size = contents.size
            uploaded_total = 0

            while uploaded_total < file_size
              upload_size_left = file_size - uploaded_total
              len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

              bytes_written = upload.write(contents[uploaded_total, len], len)
              uploaded_total += bytes_written
            end

            upload.commit

            object = upload.info
            expect(object.key).to eq(key_path)
            expect(object.created).to be >= time
            expect(object.content_length).to eq(contents.size)
          end
        end
      end
    end

    it 'uploading an object to a bucket with expiry date set' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          time = Time.now.to_i
          expires = time + (60 * 60)

          contents = 'hello world'

          project.upload_object(bucket_name, key_path, { expires: expires }) do |upload|
            chunk_size = 1000

            file_size = contents.size
            uploaded_total = 0

            while uploaded_total < file_size
              upload_size_left = file_size - uploaded_total
              len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

              bytes_written = upload.write(contents[uploaded_total, len], len)
              uploaded_total += bytes_written
            end

            upload.commit
          end

          object = project.stat_object(bucket_name, key_path)
          expect(object.key).to eq(key_path)
          expect(object.created).to be >= time
          expect(object.expires).to eq(expires)
          expect(object.content_length).to eq(contents.size)
          expect(object.custom).to be_empty
        end
      end
    end

    it 'uploading an object to a bucket with custom metadata set' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          time = Time.now.to_i

          contents = 'hello world'

          project.upload_object(bucket_name, key_path) do |upload|
            chunk_size = 1000

            file_size = contents.size
            uploaded_total = 0

            while uploaded_total < file_size
              upload_size_left = file_size - uploaded_total
              len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

              bytes_written = upload.write(contents[uploaded_total, len], len)
              uploaded_total += bytes_written
            end

            upload.set_custom_metadata({ foo: 'test1', bar: 123 })

            upload.commit

            object = upload.info
            expect(object.key).to eq(key_path)
            expect(object.created).to be >= time
            expect(object.content_length).to eq(contents.size)
            expect(object.custom).not_to be_empty
            expect(object.custom.size).to eq(2)
            expect(object.custom).to match('foo' => 'test1', 'bar' => '123')
          end
        end
      end
    end

    it "updating object's custom metadata" do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = 'hello world'
          upload_object_from_string(project, bucket_name, key_path, contents, 0, { foo: 'test1', bar: 123 })

          project.update_object_metadata(bucket_name, key_path, { foo: 'test2', cat: 456 })

          object = project.stat_object(bucket_name, key_path)
          expect(object.key).to eq(key_path)
          expect(object.content_length).to eq(contents.size)
          expect(object.custom).not_to be_empty
          expect(object.custom.size).to eq(2)
          expect(object.custom).to match('foo' => 'test2', 'cat' => '456')
        end
      end
    end

    it 'getting a stat of an object' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = 'hello world'
          time = Time.now.to_i
          upload_object_from_string(project, bucket_name, key_path, contents)

          object = project.stat_object(bucket_name, key_path)
          expect(object.key).to eq(key_path)
          expect(object.created).to be >= time
          expect(object.expires).to eq(0)
          expect(object.content_length).to eq(contents.size)
          expect(object.custom).to be_empty
        end
      end
    end

    it "raises error if getting a stat of an object that doesn't exist" do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          expect { project.stat_object(bucket_name, SecureRandom.hex(8)) }.to raise_error(described_class::ObjectKeyNotFoundError)
        end
      end
    end

    it 'downloading an object from bucket into bytes array' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = 'hello world'
          md5_hash1 = Digest::MD5.hexdigest(contents)

          upload_object_from_string(project, bucket_name, key_path, contents)

          downloaded_data = []

          project.download_object(bucket_name, key_path) do |download|
            object = download.info
            file_size = object.content_length

            chunk_size = 1000
            downloaded_total = 0

            loop do
              download_size_left = file_size - downloaded_total
              len = chunk_size <= 0 ? download_size_left : [chunk_size, download_size_left].min

              bytes_read, is_eof = download.read(downloaded_data, len)
              downloaded_total += bytes_read

              break if is_eof
            end
          end

          data_str = downloaded_data.pack('C*').force_encoding('UTF-8')
          md5_hash2 = Digest::MD5.hexdigest(data_str)
          expect(md5_hash1).to eq(md5_hash2)
        end
      end
    end

    it 'downloading an object from bucket into bytes array with offset and length parameters set' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = 'hello world'

          upload_object_from_string(project, bucket_name, key_path, contents)

          downloaded_data = []

          project.download_object(bucket_name, key_path, { offset: 1, length: 4 }) do |download|
            object = download.info
            file_size = object.content_length

            chunk_size = 1000
            downloaded_total = 0

            loop do
              download_size_left = file_size - downloaded_total
              len = chunk_size <= 0 ? download_size_left : [chunk_size, download_size_left].min

              bytes_read, is_eof = download.read(downloaded_data, len)
              downloaded_total += bytes_read

              break if is_eof
            end
          end

          data_str = downloaded_data.pack('C*').force_encoding('UTF-8')
          expect(data_str).to eq('ello')
        end
      end
    end

    it 'iterating objects in a bucket' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = 'hello world'
          upload_object_from_string(project, bucket_name, 'test1.txt', contents)
          upload_object_from_string(project, bucket_name, 'test2.txt', contents)
          upload_object_from_string(project, bucket_name, 'foo/test3.txt', contents)

          objects = []

          project.list_objects(bucket_name) do |it|
            while it.next?
              object = it.item
              objects << object
            end
          end

          expect(objects.size).to eq(3)
          expect(objects.map(&:key)).to match_array(['test1.txt', 'test2.txt', 'foo/'])
          objects.each do |object|
            expect(object.is_prefix).to be(object.key.end_with?('/'))
            expect(object.created).to eq(0)
            expect(object.expires).to eq(0)
            expect(object.content_length).to eq(0)
            expect(object.custom).to be_empty
          end
        end
      end
    end

    it 'iterating objects in a bucket with system data flag set' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          time = Time.now.to_i
          upload_object_from_string(project, bucket_name, 'test1.txt', 'andy')
          upload_object_from_string(project, bucket_name, 'test2.txt', 'bob')
          upload_object_from_string(project, bucket_name, 'foo/test3.txt', 'cindy')

          objects = []

          project.list_objects(bucket_name, { system: true }) do |it|
            while it.next?
              object = it.item
              objects << object
            end
          end

          expect(objects.size).to eq(3)
          expect(objects.map(&:key)).to match_array(['test1.txt', 'test2.txt', 'foo/'])
          objects.each do |object|
            expect(object.is_prefix).to be(object.key.end_with?('/'))
            expect(object.created).to be >= time unless object.is_prefix
            expect(object.expires).to eq(0)
            expect(object.custom).to be_empty

            case object.key
            when 'test1.txt'
              expect(object.content_length).to eq('andy'.size)
            when 'test2.txt'
              expect(object.content_length).to eq('bob'.size)
            when 'foo/'
              expect(object.content_length).to eq(0)
            end
          end
        end
      end
    end

    it 'iterating objects in a bucket with custom metadata flag set' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          upload_object_from_string(project, bucket_name, 'test1.txt', 'andy', 0, { a: '1' })
          upload_object_from_string(project, bucket_name, 'test2.txt', 'bob', 0, { a: '2' })
          upload_object_from_string(project, bucket_name, 'foo/test3.txt', 'cindy', 0, { a: '3' })

          objects = []

          project.list_objects(bucket_name, { custom: true }) do |it|
            while it.next?
              object = it.item
              objects << object
            end
          end

          expect(objects.size).to eq(3)
          expect(objects.map(&:key)).to match_array(['test1.txt', 'test2.txt', 'foo/'])
          objects.each do |object|
            expect(object.is_prefix).to be(object.key.end_with?('/'))

            case object.key
            when 'test1.txt'
              expect(object.custom).not_to be_empty
              expect(object.custom).to match('a' => '1')
            when 'test2.txt'
              expect(object.custom).not_to be_empty
              expect(object.custom).to match('a' => '2')
            when 'foo/'
              expect(object.custom).to be_empty
            end
          end
        end
      end
    end

    it 'iterating objects in a bucket recursively' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          time = Time.now.to_i
          upload_object_from_string(project, bucket_name, 'test1.txt', 'andy')
          upload_object_from_string(project, bucket_name, 'foo/test2.txt', 'bob')
          upload_object_from_string(project, bucket_name, 'foo/test3.txt', 'cindy')
          upload_object_from_string(project, bucket_name, 'bar/test4.txt', 'daniel')

          objects = []

          project.list_objects(bucket_name, { recursive: true, system: true }) do |it|
            while it.next?
              object = it.item
              objects << object
            end
          end

          expect(objects.size).to eq(4)
          expect(objects.map(&:key)).to match_array(['test1.txt', 'foo/test2.txt', 'foo/test3.txt', 'bar/test4.txt'])
          objects.each do |object|
            expect(object.is_prefix).to be(false)
            expect(object.created).to be >= time
            expect(object.expires).to eq(0)
            expect(object.custom).to be_empty

            case object.key
            when 'test1.txt'
              expect(object.content_length).to eq('andy'.size)
            when 'foo/test2.txt'
              expect(object.content_length).to eq('bob'.size)
            when 'foo/test3.txt'
              expect(object.content_length).to eq('cindy'.size)
            when 'bar/test4.txt'
              expect(object.content_length).to eq('daniel'.size)
            end
          end
        end
      end
    end

    it 'iterating objects in a bucket with prefix' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          upload_object_from_string(project, bucket_name, 'test1.txt', 'andy')
          upload_object_from_string(project, bucket_name, 'foo/test2.txt', 'bob')
          upload_object_from_string(project, bucket_name, 'foo/test3.txt', 'cindy')
          upload_object_from_string(project, bucket_name, 'bar/test4.txt', 'daniel')

          objects = []

          project.list_objects(bucket_name, { prefix: 'foo/' }) do |it|
            while it.next?
              object = it.item
              objects << object
            end
          end

          expect(objects.size).to eq(2)
          expect(objects.map(&:key)).to match_array(['foo/test2.txt', 'foo/test3.txt'])
        end
      end
    end

    it 'iterating objects in a bucket with cursor' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          upload_object_from_string(project, bucket_name, 'test1.txt', 'andy')
          upload_object_from_string(project, bucket_name, 'foo/test2.txt', 'bob')
          upload_object_from_string(project, bucket_name, 'foo/test3.txt', 'cindy')
          upload_object_from_string(project, bucket_name, 'bar/test4.txt', 'daniel')

          object_keys = []

          # collect the object keys first
          project.list_objects(bucket_name, { recursive: true }) do |it|
            while it.next?
              object = it.item
              object_keys << object.key
            end
          end

          # the iterating would start from after second object
          cursor = object_keys[1]

          expected_keys = object_keys[2...]

          objects = []

          project.list_objects(bucket_name, { cursor: cursor, recursive: true }) do |it|
            while it.next?
              object = it.item
              objects << object
            end
          end

          expect(objects.size).to eq(expected_keys.size)
          expect(objects.map(&:key)).to match_array(expected_keys)
        end
      end
    end

    it 'copying an object' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)
          project.ensure_bucket(bucket_name2)

          contents = 'hello world'
          upload_object_from_string(project, bucket_name, key_path, contents)

          key_path2 = 'bar/test2.txt'
          expect { project.stat_object(bucket_name2, key_path2) }.to raise_error(described_class::ObjectKeyNotFoundError)

          time = Time.now.to_i
          project.copy_object(bucket_name, key_path, bucket_name2, key_path2)

          object = project.stat_object(bucket_name, key_path)
          expect(object.key).to eq(key_path)
          expect(object.content_length).to eq(contents.size)

          object = project.stat_object(bucket_name2, key_path2)
          expect(object.key).to eq(key_path2)
          expect(object.created).to be >= time
          expect(object.created).not_to be < time
          expect(object.content_length).to eq(contents.size)
        end
      end
    end

    it 'moving an object' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)
          project.ensure_bucket(bucket_name2)

          time = Time.now.to_i
          contents = 'hello world'
          upload_object_from_string(project, bucket_name, key_path, contents)

          key_path2 = 'bar/test2.txt'
          expect { project.stat_object(bucket_name2, key_path2) }.to raise_error(described_class::ObjectKeyNotFoundError)

          project.move_object(bucket_name, key_path, bucket_name2, key_path2)

          expect { project.stat_object(bucket_name, key_path) }.to raise_error(described_class::ObjectKeyNotFoundError)

          object = project.stat_object(bucket_name2, key_path2)
          expect(object.key).to eq(key_path2)
          expect(object.created).to be >= time
          expect(object.created).not_to be < time
          expect(object.content_length).to eq(contents.size)
        end
      end
    end

    it 'deleting an object in a bucket' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = 'hello world'
          upload_object_from_string(project, bucket_name, key_path, contents)

          project.delete_object(bucket_name, key_path)

          expect { project.stat_object(bucket_name, key_path) }.to raise_error(described_class::ObjectKeyNotFoundError)
        end
      end
    end

    it "doesn't raise error if deleting object that doesn't exist" do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          expect { project.delete_object(bucket_name, SecureRandom.hex(8)) }.not_to raise_error
        end
      end
    end
  end

  context '[Multipart Upload Tests]' do
    it 'uploading an object to a bucket in multipart' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          five_mib_size = 5 * 1024 * 1024
          six_mib_size = 6 * 1024 * 1024
          contents = SecureRandom.random_bytes(six_mib_size + five_mib_size)
          md5_hash1 = Digest::MD5.hexdigest(contents)

          time = Time.now.to_i
          expires = time + (60 * 60)

          file_size = contents.size
          part_size = six_mib_size
          part_count = 2

          chunk_size = 1000
          uploaded_total = 0

          upload_info = project.begin_upload(bucket_name, key_path, { expires: expires })

          part_count.times do |i|
            project.upload_part(bucket_name, key_path, upload_info.upload_id, i + 1) do |part_upload|
              upload_size = [(i + 1) * part_size, file_size].min

              while uploaded_total < upload_size
                upload_size_left = upload_size - uploaded_total
                len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

                bytes_written = part_upload.write(contents[uploaded_total, len], len)
                uploaded_total += bytes_written
              end

              part_upload.set_etag('test')

              part_upload.commit

              upload_part = part_upload.info
              expect(upload_part.part_number).to eq(i + 1)
              expect(upload_part.size).to eq(i != (part_count - 1) ? six_mib_size : five_mib_size)
              expect(upload_part.etag).to eq('test')
            end
          end

          upload_options = {
            custom_metadata: { foo: 'test1', bar: 123 }
          }
          project.commit_upload(bucket_name, key_path, upload_info.upload_id, upload_options)

          object = project.stat_object(bucket_name, key_path)
          expect(object.key).to eq(key_path)
          expect(object.created).to be >= time
          expect(object.expires).to eq(expires)
          expect(object.content_length).to eq(contents.size)
          expect(object.custom).not_to be_empty
          expect(object.custom).to match('foo' => 'test1', 'bar' => '123')

          data_str = download_object_as_string(project, bucket_name, key_path, 0)
          md5_hash2 = Digest::MD5.hexdigest(data_str)
          expect(md5_hash1).to eq(md5_hash2)
        end
      end
    end

    it 'raises error if uploading an object in multipart with part upload size below the minimum size (5 MiB)' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = '1234567890'

          file_size = contents.size
          part_size = 5
          part_count = 2

          chunk_size = 0
          uploaded_total = 0

          upload_info = project.begin_upload(bucket_name, key_path)

          part_count.times do |i|
            project.upload_part(bucket_name, key_path, upload_info.upload_id, i + 1) do |part_upload|
              upload_size = [(i + 1) * part_size, file_size].min

              while uploaded_total < upload_size
                upload_size_left = upload_size - uploaded_total
                len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

                bytes_written = part_upload.write(contents[uploaded_total, len], len)
                uploaded_total += bytes_written
              end

              part_upload.commit
            end
          end

          expect { project.commit_upload(bucket_name, key_path, upload_info.upload_id) }.to raise_error(described_class::InternalError)
        end
      end
    end

    it 'aborting multipart upload' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = '1234567890'

          file_size = contents.size
          part_size = 5
          part_count = 2

          chunk_size = 0
          uploaded_total = 0

          upload_info = project.begin_upload(bucket_name, key_path)

          part_count.times do |i|
            project.upload_part(bucket_name, key_path, upload_info.upload_id, i + 1) do |part_upload|
              upload_size = [(i + 1) * part_size, file_size].min

              while uploaded_total < upload_size
                upload_size_left = upload_size - uploaded_total
                len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

                bytes_written = part_upload.write(contents[uploaded_total, len], len)
                uploaded_total += bytes_written
              end

              part_upload.commit
            end
          end

          project.abort_upload(bucket_name, key_path, upload_info.upload_id)

          expect { project.stat_object(bucket_name, key_path) }.to raise_error(described_class::ObjectKeyNotFoundError)
        end
      end
    end

    it 'iterating pending multipart uploads' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          key_paths = ['test.txt', 'foo/test.txt', 'bar/test2.txt']

          key_paths.each do |key_path_val|
            project.begin_upload(bucket_name, key_path_val)
          end

          upload_infos = []

          project.list_uploads(bucket_name) do |it|
            while it.next?
              upload_info = it.item
              upload_infos << upload_info
            end
          end

          expect(upload_infos.map(&:key)).to match_array(['test.txt', 'foo/', 'bar/'])
          upload_infos.each do |upload_info|
            expect(upload_info.is_prefix).to be(upload_info.key.end_with?('/'))
          end
        end
      end
    end

    it 'iterating pending multipart uploads recursively' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          key_paths = ['test.txt', 'foo/test.txt', 'bar/test2.txt']

          key_paths.each do |key_path_val|
            project.begin_upload(bucket_name, key_path_val)
          end

          upload_infos = []

          project.list_uploads(bucket_name, { recursive: true }) do |it|
            while it.next?
              upload_info = it.item
              upload_infos << upload_info
            end
          end

          expect(upload_infos.map(&:key)).to match_array(key_paths)
        end
      end
    end

    it 'iterating upload parts' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = '12345678901234567890'

          file_size = contents.size
          part_size = 5
          part_count = 4

          chunk_size = 0
          uploaded_total = 0

          time = Time.now.to_i

          upload_info = project.begin_upload(bucket_name, key_path)

          part_count.times do |i|
            project.upload_part(bucket_name, key_path, upload_info.upload_id, i + 1) do |part_upload|
              upload_size = [(i + 1) * part_size, file_size].min

              while uploaded_total < upload_size
                upload_size_left = upload_size - uploaded_total
                len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

                bytes_written = part_upload.write(contents[uploaded_total, len], len)
                uploaded_total += bytes_written
              end

              part_upload.set_etag('test')

              part_upload.commit
            end
          end

          upload_parts = []

          project.list_upload_parts(bucket_name, key_path, upload_info.upload_id) do |it|
            while it.next?
              upload_part = it.item
              upload_parts << upload_part
            end
          end

          expect(upload_parts.size).to eq(part_count)
          upload_parts.each_with_index do |upload_part, i|
            expect(upload_part.part_number).to eq(i + 1)
            expect(upload_part.size).to eq(part_size)
            expect(upload_part.modified).to be >= time
            expect(upload_part.etag).to eq('test')
          end
        end
      end
    end

    it 'iterating upload parts with cursor' do
      described_class.parse_access(access_string) do |access|
        access.open_project do |project|
          project.ensure_bucket(bucket_name)

          contents = '12345678901234567890'

          file_size = contents.size
          part_size = 5
          part_count = 4

          chunk_size = 0
          uploaded_total = 0

          time = Time.now.to_i

          upload_info = project.begin_upload(bucket_name, key_path)

          part_count.times do |i|
            project.upload_part(bucket_name, key_path, upload_info.upload_id, i + 1) do |part_upload|
              upload_size = [(i + 1) * part_size, file_size].min

              while uploaded_total < upload_size
                upload_size_left = upload_size - uploaded_total
                len = chunk_size <= 0 ? upload_size_left : [chunk_size, upload_size_left].min

                bytes_written = part_upload.write(contents[uploaded_total, len], len)
                uploaded_total += bytes_written
              end

              part_upload.set_etag('test')

              part_upload.commit
            end
          end

          upload_parts = []

          # the iterating would start from third upload part
          project.list_upload_parts(bucket_name, key_path, upload_info.upload_id, { cursor: 2 }) do |it|
            while it.next?
              upload_part = it.item
              upload_parts << upload_part
            end
          end

          expect(upload_parts.size).to eq(part_count - 2)
          upload_parts.each_with_index do |upload_part, i|
            expect(upload_part.part_number).to eq(3 + i)
            expect(upload_part.size).to eq(part_size)
            expect(upload_part.modified).to be >= time
            expect(upload_part.etag).to eq('test')
          end
        end
      end
    end
  end

  context '[Misc Tests]' do
    it 'checking if there is data stored in the global map' do
      expect(described_class.internal_universe_is_empty?).to be(true)

      described_class.parse_access(access_string) do |_access|
        expect(described_class.internal_universe_is_empty?).to be(false)
      end

      expect(described_class.internal_universe_is_empty?).to be(true)
    end
  end
end
