# Chimp & See Data Pipeline
This folder contains the scripts used to process raw Chimp & See videos as given
by the science team.

General workflow is to scan over every video on a given hard drive and generate
subjects within a MySQL database on the eventual subjects that will be created.
The videos are then uploaded to S3. Consumer instances are created running the
consumer.rb script. On the machine with the MySQL database of subjects,
producer.rb is run, which fills a SQS. Consumer machines pulls from the queue,
download the raw video from S3, encode them, and moves the newly encoded video
to it's eventual location that will be referenced on the subject.

## Files
- config.yml - General configuration used throughout these scripts. Attempted to
  avoid duplication of configuration cross scripts.
- consumer.rb - The script that should be run on all machines you want to
  consume the queue. Does the actual video encoding.
- consumer.yml - Configuration for consumer.rb
- deploy.rb - A script to quickly deploy consumer.rb to all EC2 instances with
  the chimps-slave tag.
- generate_manifest.rb - Used to generate the manifest for ingestion into
  Ouroboros. Accesses the MySQL db referenced in configuration.
- groups_manifest.rb - Scans a provided hard drive, generating group entries for
  each source site found. Also creates a fake name which is used by the
  community to reference a specific site.
- producer.rb - Queries MySQL and generates SQS messages for each subject that
  should be created.
- producer.yml - Configuration for producer.rb
- README.md - This file
- subjects_manifest.rb - Scans the specified input path for videos, running
  ffprobe on each to attempt to filter out videos with encoding errors or other
  problems. Subjects are created in MySQL for those that pass inspection.
- user_data.txt - The bash script that initialized the chimps-slave instances to
  a consistent place.

## Process
Loosely:

```
docker run -it --rm -v /path/to/data/:/data/ -v $PWD/config.yml:/opt/chimps/config.yml zooniverse/chimps-subject-pipeline groups_manifest.rb
docker run -it --rm -v /path/to/data/:/data/ -v $PWD/config.yml:/opt/chimps/config.yml zooniverse/chimps-subject-pipeline subjects_manifest.rb
docker run -it --rm -v /path/to/data/:/data/ -v $PWD/config.yml:/opt/chimps/config.yml zooniverse/chimps-subject-pipeline producer.rb Folder_1 Folder_2 ...
docker run -it --rm -v /path/to/data/:/data/ -v $PWD/config.yml:/opt/chimps/config.yml zooniverse/chimps-subject-pipeline generate_manifest.rb Folder_1 Folder_2 ...
```

- Upload hard drive data to S3
- Run subjects_manfiest.rb and groups_manfiest.rb against the hard drive.
- Fire up as many instances as is appropriate for the data volume, using the
  user_data.txt to install dependencies. I generally used 6 c3.2xlarge which
  processed a hard drive's worth in about 4 days.
- Start the consumer.rb script on all consumer instances.
- Run producer.rb to fill SQS, which consumers will immediately start pulling
  from.
- Asynchronously to all this, run generate_manifest.rb to produce a text file
  for easy iteration over to ingest into Ouroboros.
- Create subjects in Ouroboros.
- ...
- Profit!

## Other Notes
- Uploading is done asynchronously to the above process. Use whatever tool you
  find most convenient there.
- Piping the ffmpeg that goes to both stdout and stderr to /dev/null is
  important, as apparently you can fill those input buffers if you don't read
  from them constantly. ffmpeg likes to just plop any output at all to stderr,
  so it's not like you are dumping potentially useful error messages down the
  drain.
