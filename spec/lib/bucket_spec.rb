# frozen_string_literal: true

module UplinkTest
  describe Uplink do
    context '[Bucket Tests]' do
      it 'creating a new bucket' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            time = Time.now.to_i
            bucket = project.create_bucket(bucket_name)
            expect(bucket.name).to eq(bucket_name)
            expect(bucket.created).to be >= time
          end
        end
      end

      it 'raises error if creating a bucket with name that already exists' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.create_bucket(bucket_name)

            expect { project.create_bucket(bucket_name) }.to raise_error(described_class::BucketAlreadyExistsError)
          end
        end
      end

      it "ensuring a bucket (creating a new bucket if doesn't exist but doesn't raise error if bucket already exists)" do
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            expect { project.stat_bucket(SecureRandom.hex(8)) }.to raise_error(described_class::BucketNotFoundError)
          end
        end
      end

      it 'iterating buckets in a project' do
        cleanup(ACCESS_STRING)

        described_class.parse_access(ACCESS_STRING) do |access|
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
        cleanup(ACCESS_STRING)

        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)

            project.delete_bucket(bucket_name)

            expect { project.stat_bucket(bucket_name) }.to raise_error(described_class::BucketNotFoundError)
          end
        end
      end

      it 'deleting a bucket with objects' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            project.ensure_bucket(bucket_name)
            upload_object_from_string(project, bucket_name, KEY_PATH, 'hello world')

            project.delete_bucket_with_objects(bucket_name)

            expect { project.stat_object(bucket_name, KEY_PATH) }.to raise_error(described_class::ObjectKeyNotFoundError)
            expect { project.stat_bucket(bucket_name) }.to raise_error(described_class::BucketNotFoundError)
          end
        end
      end

      it "raises error if deleting a bucket that doesn't exist" do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            expect { project.delete_bucket(SecureRandom.hex(8)) }.to raise_error(described_class::BucketNotFoundError)
            expect { project.delete_bucket_with_objects(SecureRandom.hex(8)) }.to raise_error(described_class::BucketNotFoundError)
          end
        end
      end
    end
  end
end
