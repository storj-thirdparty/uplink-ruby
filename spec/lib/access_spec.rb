# frozen_string_literal: true

module UplinkTest
  describe Uplink do
    context '[Access Tests]' do
      it 'parsing an access string' do
        expect { described_class.parse_access(ACCESS_STRING) { |_access| nil } }.not_to raise_error
      end

      it 'requesting access with passphrase' do
        expect { described_class.request_access_with_passphrase(SATELLITE_ADDRESS, API_KEY, PASSPHRASE) { |_access| nil } }.not_to raise_error
      end

      it 'requesting access with passphrase and with config' do
        config = {
          user_agent: 'Test/1.0',
          dial_timeout_milliseconds: 10_000
        }
        expect { described_class.request_access_with_passphrase_and_config(config, SATELLITE_ADDRESS, API_KEY, PASSPHRASE) { |_access| nil } }.not_to raise_error
      end

      it 'returning satellite address' do
        described_class.parse_access(ACCESS_STRING) do |access|
          address = access.satellite_address
          expect(address).to eq(SATELLITE_ADDRESS)
        end
      end

      it 'serializing access string' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access_str = access.serialize
          expect(access_str).to eq(ACCESS_STRING)
        end
      end

      it 'sharing an access for any buckets' do
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
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
        described_class.parse_access(ACCESS_STRING) do |access|
          described_class.derive_encryption_key('my-password', '123', 3) do |encryption_key|
            expect { access.override_encryption_key(bucket_name, 'foo/', encryption_key) }.not_to raise_error
          end
        end
      end

      it 'registering an edge access' do
        described_class.parse_access(ACCESS_STRING) do |access|
          permission = { allow_download: true, allow_list: true }
          prefixes = [
            { bucket: bucket_name }
          ]

          access.share(permission, prefixes) do |shared_access|
            edge_credential = shared_access.edge_register_access({ auth_service_address: AUTH_SERVICE_ADDRESS })
            expect(edge_credential.access_key_id).not_to be_empty
            expect(edge_credential.secret_key).not_to be_empty
            expect(edge_credential.endpoint).to eq('https://gateway.storjshare.io')
          end
        end
      end

      it 'creating a direct share url for an object' do
        described_class.parse_access(ACCESS_STRING) do |access|
          contents = 'hello world'
          access.open_project do |project|
            project.ensure_bucket(bucket_name)
            upload_object_from_string(project, bucket_name, KEY_PATH, contents)
          end

          permission = { allow_download: true }
          prefixes = [
            { bucket: bucket_name }
          ]

          access.share(permission, prefixes) do |shared_access|
            edge_credential = shared_access.edge_register_access({ auth_service_address: AUTH_SERVICE_ADDRESS }, { is_public: true })
            share_url = edge_credential.join_share_url(LINK_SHARING_ADDRESS, bucket_name, KEY_PATH, { raw: true })
            downloaded_contents = Net::HTTP.get(URI.parse(share_url))
            expect(downloaded_contents).to eq(contents)
          end
        end
      end

      it 'creating a page share url for an object' do
        described_class.parse_access(ACCESS_STRING) do |access|
          contents = 'hello world'
          access.open_project do |project|
            project.ensure_bucket(bucket_name)
            upload_object_from_string(project, bucket_name, KEY_PATH, contents)
          end

          permission = { allow_download: true }
          prefixes = [
            { bucket: bucket_name }
          ]

          access.share(permission, prefixes) do |shared_access|
            edge_credential = shared_access.edge_register_access({ auth_service_address: AUTH_SERVICE_ADDRESS }, { is_public: true })
            share_url = edge_credential.join_share_url(LINK_SHARING_ADDRESS, bucket_name, KEY_PATH, { raw: false })
            expect(share_url).to match("#{LINK_SHARING_ADDRESS}/s/[a-z].*/#{bucket_name}/#{KEY_PATH}")
          end
        end
      end

      it 'creating a page share url for a bucket' do
        described_class.parse_access(ACCESS_STRING) do |access|
          contents = 'hello world'
          access.open_project do |project|
            project.ensure_bucket(bucket_name)
            upload_object_from_string(project, bucket_name, KEY_PATH, contents)
          end

          permission = { allow_download: true, allow_list: true }
          prefixes = [
            { bucket: bucket_name }
          ]

          access.share(permission, prefixes) do |shared_access|
            edge_credential = shared_access.edge_register_access({ auth_service_address: AUTH_SERVICE_ADDRESS }, { is_public: true })
            share_url = edge_credential.join_share_url(LINK_SHARING_ADDRESS, bucket_name, nil, { raw: false })
            expect(share_url).to match("#{LINK_SHARING_ADDRESS}/s/[a-z].*/#{bucket_name}")
          end
        end
      end
    end
  end
end
