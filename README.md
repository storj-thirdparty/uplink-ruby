# <b>Uplink-Ruby</b>

Ruby bindings to the [libuplink](https://github.com/storj/uplink-c) Storj API library.

## <b> Getting Started </b>

### Prerequisites
* Clone [uplink-c](https://github.com/storj/uplink-c) repository.
* Check out the release version `v1.8.0`.
    ```bash
    $ git fetch --tags
    $ git checkout tags/v1.8.0
    ```
* Run `make build` to build the uplink-c library.
* The `libuplink.so` file should be created in the `.build` folder.
* Add the `libuplink.so` location path into `LD_LIBRARY_PATH` environment variable
    ```bash
    $ export LD_LIBRARY_PATH=<libuplink.so_folder_path>:$LD_LIBRARY_PATH
    ```

### Installation

Add this line to your application's Gemfile:

```ruby
gem 'uplink-ruby', '~> 1.8.0'
```

or from the git:

```ruby
gem 'uplink-ruby', git: 'https://github.com/storj-thirdparty/uplink-ruby', tag: 'v1.8.0'
```

Make sure the major & minor version of the gem or git tag matches the uplink-c release version.


### Running the Tests
* Create a [Storj](https://www.storj.io/) account.
* In the Storj Dashboard, create an Access Grant and set the access grant key to `UPLINK_0_ACCESS` environment variable

    ```bash
    $ export UPLINK_0_ACCESS="15W8fjomdWMwh4cdbZx5YmDQpQsc8EN..."
    ```
* Create a Storj CLI Access key, which consists of Satellite Address and API key, and set them to `UPLINK_0_SATELLITE_ADDR` and `UPLINK_0_APIKEY` environment variables
    ```bash
    $ export UPLINK_0_SATELLITE_ADDR="125WTSDqyNZVcEU95Tbdf..."
    $ export UPLINK_0_APIKEY="11MKmbWfdCCVzgCso5reTK..."
    ```
* Create a passphrase and set it to `UPLINK_0_PASSPHRASE` environment variable
    ```bash
    $ export UPLINK_0_PASSPHRASE="mypassphrase"
    ```

* Install gem dependencies

  ```bash
  $ bundle install
  ```

* Run the tests
  ```bash
  $ rspec
  ```

## <b> Usage </b>

Example for basic operations

```ruby
require 'uplink'

access_string = ENV.fetch('UPLINK_ACCESS_GRANT')

bucket_name = 'bucket1'
key_path = 'foo/test.txt'

Uplink.parse_access(access_string) do |access|
  access.open_project do |project|
    # Create a bucket if it doesn't exist
    project.ensure_bucket(bucket_name)

    # Upload an object into a bucket
    contents = 'Hello World'
    project.upload_object(bucket_name, key_path) do |upload|
      file_size = contents.length
      uploaded_total = 0

      while uploaded_total < file_size
        len = file_size - uploaded_total

        bytes_written = upload.write(contents[uploaded_total, len], len)
        uploaded_total += bytes_written
      end

      upload.commit
    end

    # Get info of an object
    object = project.stat_object(bucket_name, key_path)
    puts "Object info: key=#{object.key}, created_time=#{object.created}, length=#{object.content_length}"

    # Download an object
    downloaded_data = []
    project.download_object(bucket_name, key_path) do |download|
      file_size = 0

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
    puts "Object data=#{data_str}"

    # Iterate objects in a bucket
    project.list_objects(bucket_name, { recursive: true, system: true }) do |it|
      while it.next?
        object = it.item
        puts "Object info: key=#{object.key}, created_time=#{object.created}, length=#{object.content_length}"
      end
    end

    # Delete an object
    project.delete_object(bucket_name, key_path)

    # Delete a bucket
    project.delete_bucket(bucket_name)
  end
end
```

Example for multipart uploads

```ruby
require 'uplink'
require 'securerandom'

access_string = ENV.fetch('UPLINK_ACCESS_GRANT')

bucket_name = 'bucket1'
key_path = 'foo/test.txt'

Uplink.parse_access(access_string) do |access|
  access.open_project do |project|
    project.ensure_bucket(bucket_name)

    five_mib_size = 5 * 1024 * 1024
    six_mib_size = 6 * 1024 * 1024

    # create 11 MiB size of sample data for upload
    contents = SecureRandom.random_bytes(six_mib_size + five_mib_size)

    file_size = contents.size
    part_size = six_mib_size

    chunk_size = 1000
    uploaded_total = 0

    upload_info = project.begin_upload(bucket_name, key_path)

    # divide the upload into 2 parts with a maximum upload size of 6 MiB for each part
    2.times do |i|
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

    project.commit_upload(bucket_name, key_path, upload_info.upload_id)
  end
end
```

Example for creating a share link

```ruby
require 'uplink'

access_string = ENV.fetch('UPLINK_ACCESS_GRANT')

auth_service_address = 'auth.storjshare.io:7777'
link_sharing_address = 'https://link.storjshare.io'

bucket_name = 'bucket1'
key_path = 'foo/test.txt'

Uplink.parse_access(access_string) do |access|
  permission = { allow_download: true }
  prefixes = [
    { bucket: bucket_name }
  ]

  access.share(permission, prefixes) do |shared_access| # create a shared access with appropriate permissions
    edge_credential = shared_access.edge_register_access({ auth_service_address: auth_service_address }, { is_public: true })

    share_url = edge_credential.join_share_url(link_sharing_address, bucket_name, key_path, { raw: false }) # set `raw` to true for a direct share link

    puts share_url  # https://link.storjshare.io/s/jwp3kkwbcevjhis.../bucket1/foo/test.txt
  end
end
```

For more usage examples, check the tests in `spec` folder.
