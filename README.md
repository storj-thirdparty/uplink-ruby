# <b>Uplink-Ruby</b>

Ruby bindings to the [libuplink](https://github.com/storj/uplink-c) Storj API library.

## <b> Getting Started </b>

### Prerequisites
* Build the [uplink-c](https://github.com/storj/uplink-c) library.
* The `libuplink.so` file should be created in the `.build` folder.
* Add the `libuplink.so` location path into `LD_LIBRARY_PATH` environment variable
    ```bash
    $ export LD_LIBRARY_PATH=<libuplink.so_folder_path>:$LD_LIBRARY_PATH
    ```

### Installation

```bash
gem install uplink-ruby
```

Or add this line to your application's Gemfile:

```ruby
gem 'uplink-ruby'
```

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

* Run the tests
  ```bash
  $ rspec
  ```

## <b> Usage </b>

Example for basic operations

```ruby
  access_string = ENV.fetch('UPLINK_ACCESS_GRANT')

  Uplink.parse_access(access_string) do |access|
    access.open_project do |project|
      bucket_name = 'bucket1'
      key_path = 'foo/test.txt'

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

For more usage examples, check the tests in `spec` folder.