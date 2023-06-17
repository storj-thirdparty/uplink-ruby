# frozen_string_literal: true

module UplinkTest
  describe Uplink do
    context '[Object Tests]' do
      it 'uploading an object to a bucket' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            time = Time.now.to_i

            contents = 'hello world'

            project.upload_object(bucket_name, KEY_PATH) do |upload|
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
              expect(object.key).to eq(KEY_PATH)
              expect(object.created).to be >= time
              expect(object.content_length).to eq(contents.size)
            end
          end
        end
      end

      it 'uploading an object to a bucket with expiry date set' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            time = Time.now.to_i
            expires = time + (60 * 60)

            contents = 'hello world'

            project.upload_object(bucket_name, KEY_PATH, { expires: expires }) do |upload|
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

            object = project.stat_object(bucket_name, KEY_PATH)
            expect(object.key).to eq(KEY_PATH)
            expect(object.created).to be >= time
            expect(object.expires).to eq(expires)
            expect(object.content_length).to eq(contents.size)
            expect(object.custom).to be_empty
          end
        end
      end

      it 'uploading an object to a bucket with custom metadata set' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            time = Time.now.to_i

            contents = 'hello world'

            project.upload_object(bucket_name, KEY_PATH) do |upload|
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
              expect(object.key).to eq(KEY_PATH)
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
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = 'hello world'
            upload_object_from_string(project, bucket_name, KEY_PATH, contents, 0, { foo: 'test1', bar: 123 })

            project.update_object_metadata(bucket_name, KEY_PATH, { foo: 'test2', cat: 456 })

            object = project.stat_object(bucket_name, KEY_PATH)
            expect(object.key).to eq(KEY_PATH)
            expect(object.content_length).to eq(contents.size)
            expect(object.custom).not_to be_empty
            expect(object.custom.size).to eq(2)
            expect(object.custom).to match('foo' => 'test2', 'cat' => '456')
          end
        end
      end

      it 'getting a stat of an object' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = 'hello world'
            time = Time.now.to_i
            upload_object_from_string(project, bucket_name, KEY_PATH, contents)

            object = project.stat_object(bucket_name, KEY_PATH)
            expect(object.key).to eq(KEY_PATH)
            expect(object.created).to be >= time
            expect(object.expires).to eq(0)
            expect(object.content_length).to eq(contents.size)
            expect(object.custom).to be_empty
          end
        end
      end

      it "raises error if getting a stat of an object that doesn't exist" do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            expect { project.stat_object(bucket_name, SecureRandom.hex(8)) }.to raise_error(described_class::ObjectKeyNotFoundError)
          end
        end
      end

      it 'downloading an object from bucket into bytes array' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = 'hello world'
            md5_hash1 = Digest::MD5.hexdigest(contents)

            upload_object_from_string(project, bucket_name, KEY_PATH, contents)

            downloaded_data = []

            project.download_object(bucket_name, KEY_PATH) do |download|
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
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = 'hello world'

            upload_object_from_string(project, bucket_name, KEY_PATH, contents)

            downloaded_data = []

            project.download_object(bucket_name, KEY_PATH, { offset: 1, length: 4 }) do |download|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)
            project.ensure_bucket(bucket_name2)

            contents = 'hello world'
            upload_object_from_string(project, bucket_name, KEY_PATH, contents)

            key_path2 = 'bar/test2.txt'
            expect { project.stat_object(bucket_name2, key_path2) }.to raise_error(described_class::ObjectKeyNotFoundError)

            time = Time.now.to_i
            project.copy_object(bucket_name, KEY_PATH, bucket_name2, key_path2)

            object = project.stat_object(bucket_name, KEY_PATH)
            expect(object.key).to eq(KEY_PATH)
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
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)
            project.ensure_bucket(bucket_name2)

            time = Time.now.to_i
            contents = 'hello world'
            upload_object_from_string(project, bucket_name, KEY_PATH, contents)

            key_path2 = 'bar/test2.txt'
            expect { project.stat_object(bucket_name2, key_path2) }.to raise_error(described_class::ObjectKeyNotFoundError)

            project.move_object(bucket_name, KEY_PATH, bucket_name2, key_path2)

            expect { project.stat_object(bucket_name, KEY_PATH) }.to raise_error(described_class::ObjectKeyNotFoundError)

            object = project.stat_object(bucket_name2, key_path2)
            expect(object.key).to eq(key_path2)
            expect(object.created).to be >= time
            expect(object.created).not_to be < time
            expect(object.content_length).to eq(contents.size)
          end
        end
      end

      it 'deleting an object in a bucket' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = 'hello world'
            upload_object_from_string(project, bucket_name, KEY_PATH, contents)

            project.delete_object(bucket_name, KEY_PATH)

            expect { project.stat_object(bucket_name, KEY_PATH) }.to raise_error(described_class::ObjectKeyNotFoundError)
          end
        end
      end

      it "doesn't raise error if deleting object that doesn't exist" do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            expect { project.delete_object(bucket_name, SecureRandom.hex(8)) }.not_to raise_error
          end
        end
      end
    end

    context '[Multipart Upload Tests]' do
      it 'uploading an object to a bucket in multipart' do
        described_class.parse_access(ACCESS_STRING) do |access|
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

            upload_info = project.begin_upload(bucket_name, KEY_PATH, { expires: expires })

            part_count.times do |i|
              project.upload_part(bucket_name, KEY_PATH, upload_info.upload_id, i + 1) do |part_upload|
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
            project.commit_upload(bucket_name, KEY_PATH, upload_info.upload_id, upload_options)

            object = project.stat_object(bucket_name, KEY_PATH)
            expect(object.key).to eq(KEY_PATH)
            expect(object.created).to be >= time
            expect(object.expires).to eq(expires)
            expect(object.content_length).to eq(contents.size)
            expect(object.custom).not_to be_empty
            expect(object.custom).to match('foo' => 'test1', 'bar' => '123')

            data_str = download_object_as_string(project, bucket_name, KEY_PATH, 0)
            md5_hash2 = Digest::MD5.hexdigest(data_str)
            expect(md5_hash1).to eq(md5_hash2)
          end
        end
      end

      it 'raises error if uploading an object in multipart with part upload size below the minimum size (5 MiB)' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = '1234567890'

            file_size = contents.size
            part_size = 5
            part_count = 2

            chunk_size = 0
            uploaded_total = 0

            upload_info = project.begin_upload(bucket_name, KEY_PATH)

            part_count.times do |i|
              project.upload_part(bucket_name, KEY_PATH, upload_info.upload_id, i + 1) do |part_upload|
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

            expect { project.commit_upload(bucket_name, KEY_PATH, upload_info.upload_id) }.to raise_error(described_class::InternalError)
          end
        end
      end

      it 'aborting multipart upload' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = '1234567890'

            file_size = contents.size
            part_size = 5
            part_count = 2

            chunk_size = 0
            uploaded_total = 0

            upload_info = project.begin_upload(bucket_name, KEY_PATH)

            part_count.times do |i|
              project.upload_part(bucket_name, KEY_PATH, upload_info.upload_id, i + 1) do |part_upload|
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

            project.abort_upload(bucket_name, KEY_PATH, upload_info.upload_id)

            expect { project.stat_object(bucket_name, KEY_PATH) }.to raise_error(described_class::ObjectKeyNotFoundError)
          end
        end
      end

      it 'iterating pending multipart uploads' do
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = '12345678901234567890'

            file_size = contents.size
            part_size = 5
            part_count = 4

            chunk_size = 0
            uploaded_total = 0

            time = Time.now.to_i

            upload_info = project.begin_upload(bucket_name, KEY_PATH)

            part_count.times do |i|
              project.upload_part(bucket_name, KEY_PATH, upload_info.upload_id, i + 1) do |part_upload|
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

            project.list_upload_parts(bucket_name, KEY_PATH, upload_info.upload_id) do |it|
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
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            contents = '12345678901234567890'

            file_size = contents.size
            part_size = 5
            part_count = 4

            chunk_size = 0
            uploaded_total = 0

            time = Time.now.to_i

            upload_info = project.begin_upload(bucket_name, KEY_PATH)

            part_count.times do |i|
              project.upload_part(bucket_name, KEY_PATH, upload_info.upload_id, i + 1) do |part_upload|
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
            project.list_upload_parts(bucket_name, KEY_PATH, upload_info.upload_id, { cursor: 2 }) do |it|
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
  end
end
