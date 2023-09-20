# frozen_string_literal: true

module UplinkTest
  describe Uplink do
    context '[Project Tests]' do
      it 'opening a project (and closing the project automatically)' do
        described_class.parse_access(ACCESS_STRING) do |access|
          expect { access.open_project { |_project| nil } }.not_to raise_error
        end
      end

      it 'closing a project manually' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project(auto_close: false) do |project|
            expect { project.close }.not_to raise_error
          end
        end
      end

      it 'opening a project with config' do
        described_class.parse_access(ACCESS_STRING) do |access|
          config = {
            user_agent: 'Test/1.0',
            dial_timeout_milliseconds: 10_000
          }
          expect { access.open_project_with_config(config) { |_project| nil } }.not_to raise_error
        end
      end

      it 'revoking a shared access' do
        described_class.parse_access(ACCESS_STRING) do |access|
          access.open_project do |project|
            permission = { allow_upload: true, allow_delete: true, allow_download: true, allow_list: true }

            access.share(permission, nil) do |shared_access|
              shared_access.open_project do |shared_project|
                shared_project.ensure_bucket(bucket_name)
                expect { upload_object_from_string(shared_project, bucket_name, KEY_PATH, 'a') }.not_to raise_error
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
  end
end
