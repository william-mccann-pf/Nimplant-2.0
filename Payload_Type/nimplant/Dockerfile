# pull in the appropriate language's payload container from itsafeaturemythic on dockerhub
FROM python:3.8-slim-buster

# Update APT
RUN apt-get update
RUN apt-get upgrade -y
RUN apt-get install -y apt-transport-https gpg git wget unzip

# Configure Mythic Packages
RUN pip install aio_pika requests mythic-payloadtype-container==0.0.44 dynaconf==3.1.4

ENTRYPOINT ["/Mythic/mythic/payload_service.sh"]
